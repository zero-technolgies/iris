package ingest

import (
	"errors"
	"net/http"
)

var ErrInvalidSignature = errors.New("invalid webhook signature")

type Receiver interface {
	ValidateSignature(req *http.Request) error
	Parse(body []byte) ([]Event, error)
}
