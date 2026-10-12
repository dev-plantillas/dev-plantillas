package gateway

import (
	"context"
	"strings"
	"testing"
	"unicode/utf8"

	"google.golang.org/genproto/googleapis/rpc/errdetails"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestStreamErrorSinDetails(t *testing.T) {
	st, err := status.New(codes.FailedPrecondition, "el orden cambió").WithDetails(&errdetails.ErrorInfo{
		Reason: "STALE_ORDER", Domain: "issues.tekitla.internal", Metadata: map[string]string{"project_id": "p1"},
	})
	if err != nil {
		t.Fatal(err)
	}
	got := (&gw{}).streamErrorHandler(context.Background(), st.Err())
	if got.Code() != codes.FailedPrecondition || got.Message() != "el orden cambió" || len(got.Details()) != 0 {
		t.Fatalf("stream: %v %q details=%v", got.Code(), got.Message(), got.Details())
	}
}

func TestValidReason(t *testing.T) {
	for r, want := range map[string]bool{
		"STALE_ORDER": true, "E2E": true, "AB": false, "A": false, "": false,
		"FOO_": false, "_FOO": false, "1FOO": false, "stale_order": false,
		strings.Repeat("A", 63): true, strings.Repeat("A", 64): false,
	} {
		if got := validReason(r); got != want {
			t.Errorf("validReason(%q) = %v, esperaba %v", r, got, want)
		}
	}
}

func TestReasonOf(t *testing.T) {
	st, err := status.New(codes.FailedPrecondition, "x").WithDetails(
		&errdetails.ErrorInfo{Reason: "no válido"},
		&errdetails.ErrorInfo{Reason: "STALE_ORDER"},
	)
	if err != nil {
		t.Fatal(err)
	}
	if got := reasonOf(st, "FAILED_PRECONDITION"); got != "STALE_ORDER" {
		t.Fatalf("salta el ErrorInfo inválido: %q", got)
	}
	st, _ = status.New(codes.NotFound, "x").WithDetails(&errdetails.ErrorInfo{Reason: "NOT_FOUND"})
	if got := reasonOf(st, "NOT_FOUND"); got != "" {
		t.Fatalf("reason igual al código: %q", got)
	}
}

func TestTruncateSinPartirUTF8(t *testing.T) {
	s := "a" + strings.Repeat("á", 200) // 'á' ocupa 2 bytes: el corte en 300 cae en medio
	got := truncate(s, maxClientMessage)
	if len(got) > maxClientMessage || !utf8.ValidString(got) || len(got) != 299 {
		t.Fatalf("truncate: len=%d válido=%v", len(got), utf8.ValidString(got))
	}
}
