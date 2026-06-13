package main

import (
	"testing"

	"github.com/zero-technolgies/iris/src/services/ingestion/internal/config"
)

func TestWebhookReceiversRegistersArgoCD(t *testing.T) {
	receivers, err := webhookReceivers(config.Config{ArgoCDWebhookSecret: "shared-secret"})
	if err != nil {
		t.Fatalf("webhookReceivers returned error: %v", err)
	}

	if _, ok := receivers["/webhooks/argocd"]; !ok {
		t.Fatal("expected /webhooks/argocd receiver to be registered")
	}
}
