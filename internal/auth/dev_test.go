package auth

import (
	"context"
	"errors"
	"testing"
)

func TestDevVerifier(t *testing.T) {
	t.Parallel()

	principal, err := (DevVerifier{}).Verify(context.Background(), "user-a|tasks.read")
	if err != nil {
		t.Fatalf("Verify returned error: %v", err)
	}
	if principal.Subject != "user-a" {
		t.Fatalf("Subject = %q, want user-a", principal.Subject)
	}
	if !principal.HasScope("tasks.read") || principal.HasScope("tasks.write") {
		t.Fatalf("unexpected scopes: %#v", principal.Scopes)
	}
}

func TestDevVerifierRejectsEmptyToken(t *testing.T) {
	t.Parallel()

	_, err := (DevVerifier{}).Verify(context.Background(), "")
	if !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("Verify error = %v, want ErrInvalidToken", err)
	}
}
