package mcpserver

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strconv"
	"strings"
)

// httpCall es el request REST equivalente a una llamada a la herramienta.
type httpCall struct {
	path  string     // ya escapado
	query url.Values // campos que no van en el path ni en el body
	body  []byte     // nil = sin body
}

// checkTemplate rechaza los templates que no se pueden armar desde argumentos
// (comodines sueltos fuera de una variable: /v1/{name=items/*}/x/*).
func checkTemplate(tpl string) error {
	depth := 0
	for _, c := range tpl {
		switch c {
		case '{':
			depth++
		case '}':
			depth--
		case '*':
			if depth == 0 {
				return fmt.Errorf("template %q con comodín fuera de una variable", tpl)
			}
		}
	}
	if depth != 0 {
		return fmt.Errorf("template %q con llaves desbalanceadas", tpl)
	}
	return nil
}

// pathVars devuelve las variables del template (item_id, book.name, ...).
func pathVars(tpl string) []string {
	var out []string
	for rest := tpl; ; {
		i := strings.IndexByte(rest, '{')
		if i < 0 {
			return out
		}
		j := strings.IndexByte(rest[i:], '}')
		name, _, _ := strings.Cut(rest[i+1:i+j], "=")
		out = append(out, name)
		rest = rest[i+j+1:]
	}
}

// buildCall reparte los argumentos como lo espera grpc-gateway: variables del
// path, body ("*" = el resto; un campo = ese campo) y query (lo que sobra).
// args se consume: hay que pasar una copia.
func buildCall(tpl, bodyField string, args map[string]any) (*httpCall, error) {
	var sb strings.Builder
	for rest := tpl; ; {
		i := strings.IndexByte(rest, '{')
		if i < 0 {
			sb.WriteString(rest)
			break
		}
		sb.WriteString(rest[:i])
		j := strings.IndexByte(rest[i:], '}')
		name, pattern, _ := strings.Cut(rest[i+1:i+j], "=")
		v, ok := take(args, name)
		if !ok {
			return nil, fmt.Errorf("falta el argumento %q", name)
		}
		s, err := scalar(v)
		if err != nil || s == "" {
			return nil, fmt.Errorf("%q tiene que ser un valor simple y no vacío", name)
		}
		sb.WriteString(escapePath(s, strings.Contains(pattern, "/") || strings.Contains(pattern, "**")))
		rest = rest[i+j+1:]
	}
	call := &httpCall{path: sb.String(), query: url.Values{}}

	var queryArgs map[string]any
	switch bodyField {
	case "":
		queryArgs = args
	case "*":
		b, err := json.Marshal(args)
		if err != nil {
			return nil, err
		}
		call.body = b
	default:
		v, ok := args[bodyField]
		delete(args, bodyField)
		if !ok {
			v = map[string]any{}
		}
		b, err := json.Marshal(v)
		if err != nil {
			return nil, err
		}
		call.body = b
		queryArgs = args
	}
	for k, v := range queryArgs {
		if err := flatten(k, v, call.query); err != nil {
			return nil, err
		}
	}
	return call, nil
}

// take saca args[a][b]... (nombre con puntos) y lo borra del mapa.
func take(args map[string]any, dotted string) (any, bool) {
	parts := strings.Split(dotted, ".")
	m := args
	for _, p := range parts[:len(parts)-1] {
		next, ok := m[p].(map[string]any)
		if !ok {
			return nil, false
		}
		m = next
	}
	leaf := parts[len(parts)-1]
	v, ok := m[leaf]
	delete(m, leaf)
	return v, ok
}

// flatten pasa un argumento a query params: los mensajes anidados con puntos
// (page.cursor) y las listas de escalares repitiendo la clave.
func flatten(key string, v any, q url.Values) error {
	switch t := v.(type) {
	case nil:
		return nil
	case map[string]any:
		for k, sub := range t {
			if err := flatten(key+"."+k, sub, q); err != nil {
				return err
			}
		}
		return nil
	case []any:
		for _, item := range t {
			s, err := scalar(item)
			if err != nil {
				return fmt.Errorf("%q: en este RPC las listas sólo pueden tener valores simples", key)
			}
			q.Add(key, s)
		}
		return nil
	default:
		s, err := scalar(v)
		if err != nil {
			return fmt.Errorf("%q: %w", key, err)
		}
		q.Add(key, s)
		return nil
	}
}

var errNotScalar = errors.New("se esperaba un valor simple")

func scalar(v any) (string, error) {
	switch t := v.(type) {
	case string:
		return t, nil
	case json.Number:
		return t.String(), nil
	case bool:
		return strconv.FormatBool(t), nil
	}
	return "", errNotScalar
}

// escapePath escapa el valor de una variable del path. Las variables con "/"
// en el patrón ({name=shelves/*/books/*}) conservan las barras.
func escapePath(s string, keepSlashes bool) string {
	if !keepSlashes {
		return url.PathEscape(s)
	}
	parts := strings.Split(s, "/")
	for i, p := range parts {
		parts[i] = url.PathEscape(p)
	}
	return strings.Join(parts, "/")
}
