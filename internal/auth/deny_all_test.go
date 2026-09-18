package auth

import (
	"context"
	"errors"
	"testing"
)

func TestDenyAllVerifierRejectsEveryToken(t *testing.T) {
	_, err := (DenyAllVerifier{}).Verify(context.Background(), "any-token")
	if !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("Verify error = %v, want ErrInvalidToken", err)
	}
}
