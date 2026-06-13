package ingest

import (
	"crypto/hmac"
)

func SecureCompare(expected, actual []byte) bool {
	return hmac.Equal(expected, actual)
}
