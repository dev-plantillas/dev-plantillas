package mcpserver

import (
	"encoding/json"
	"strings"
	"testing"
)

func args(t *testing.T, s string) map[string]any {
	t.Helper()
	m := map[string]any{}
	dec := json.NewDecoder(strings.NewReader(s))
	dec.UseNumber()
	if err := dec.Decode(&m); err != nil {
		t.Fatal(err)
	}
	return m
}

func TestBuildCall(t *testing.T) {
	cases := []struct {
		name, tpl, body, args string
		path, query, payload  string
	}{
		{"path y query anidada", "/v1/items/{id}", "", `{"id":"a b/c","page":{"cursor":"x","limit":10}}`,
			"/v1/items/a%20b%2Fc", "page.cursor=x&page.limit=10", ""},
		{"body con el resto", "/v1/shelves/{shelf}/books", "*", `{"shelf":7,"title":"T"}`,
			"/v1/shelves/7/books", "", `{"title":"T"}`},
		{"body de un campo", "/v1/books/{book.id}", "book", `{"book":{"id":"b1","title":"T"},"update_mask":"title"}`,
			"/v1/books/b1", "update_mask=title", `{"title":"T"}`},
		{"patrón con barras", "/v1/{name=shelves/*/books/*}:archive", "*", `{"name":"shelves/1/books/2"}`,
			"/v1/shelves/1/books/2:archive", "", `{}`},
		{"lista de escalares", "/v1/items", "", `{"ids":["a","b"],"active":true}`,
			"/v1/items", "active=true&ids=a&ids=b", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			call, err := buildCall(c.tpl, c.body, args(t, c.args))
			if err != nil {
				t.Fatal(err)
			}
			if call.path != c.path || call.query.Encode() != c.query || string(call.body) != c.payload {
				t.Fatalf("path=%q query=%q body=%q", call.path, call.query.Encode(), call.body)
			}
		})
	}
}

func TestBuildCallErrores(t *testing.T) {
	cases := map[string][2]string{
		"falta variable":   {"/v1/items/{id}", `{}`},
		"variable vacía":   {"/v1/items/{id}", `{"id":""}`},
		"variable objeto":  {"/v1/items/{id}", `{"id":{"x":1}}`},
		"lista de objetos": {"/v1/items", `{"filters":[{"a":1}]}`},
	}
	for name, c := range cases {
		if _, err := buildCall(c[0], "", args(t, c[1])); err == nil {
			t.Errorf("%s: tenía que fallar", name)
		}
	}
	for _, tpl := range []string{"/v1/items/*", "/v1/{id"} {
		if checkTemplate(tpl) == nil {
			t.Errorf("checkTemplate(%q) tenía que fallar", tpl)
		}
	}
	if got := pathVars("/v1/{parent=shelves/*}/books/{book.id}"); strings.Join(got, ",") != "parent,book.id" {
		t.Errorf("pathVars = %v", got)
	}
}
