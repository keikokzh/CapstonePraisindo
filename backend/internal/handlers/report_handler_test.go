package handlers_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/capstonePraisindo/reporting-service/internal/handlers"
	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestDateRangeValidation(t *testing.T) {
	// Handler with nil repo (should error during date validation before touching DB)
	h := handlers.NewReportHandler(nil)
	r := gin.New()
	r.GET("/api/v1/reports/subscription-by-product", h.GetSubscriptionReport)

	tests := []struct {
		name         string
		url          string
		expectedCode int
		expectedBody string
	}{
		{
			name:         "To Date before From Date",
			url:          "/api/v1/reports/subscription-by-product?from_date=2026-08-31&to_date=2026-08-01",
			expectedCode: http.StatusBadRequest,
			expectedBody: "to_date tidak boleh sebelum from_date",
		},
		{
			name:         "Invalid from_date format",
			url:          "/api/v1/reports/subscription-by-product?from_date=01-08-2026&to_date=2026-08-31",
			expectedCode: http.StatusBadRequest,
			expectedBody: "Format from_date tidak valid",
		},
		{
			name:         "Missing required dates",
			url:          "/api/v1/reports/subscription-by-product",
			expectedCode: http.StatusBadRequest,
			expectedBody: "Parameter tidak valid",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			req, _ := http.NewRequest("GET", tc.url, nil)
			r.ServeHTTP(w, req)

			if w.Code != tc.expectedCode {
				t.Errorf("Expected status code %d, got %d. Body: %s", tc.expectedCode, w.Code, w.Body.String())
			}
			if tc.expectedBody != "" && !contains(w.Body.String(), tc.expectedBody) {
				t.Errorf("Expected body to contain '%s', got '%s'", tc.expectedBody, w.Body.String())
			}
		})
	}
}

func contains(haystack, needle string) bool {
	return len(haystack) >= len(needle) && (haystack == needle || (len(needle) > 0 && indexOf(haystack, needle) >= 0))
}

func indexOf(s, substr string) int {
	for i := 0; i+len(substr) <= len(s); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
