package webhook

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	admissionv1 "k8s.io/api/admission/v1"
)

func TestValidate(t *testing.T) {
	type expected struct {
		message string
		allowed bool
		code    int
	}

	tests := []struct {
		name     string
		req      []byte
		expected expected
	}{
		{
			"ValidateWithoutLabel",
			[]byte(`{
      		"request": {
      			"object": {
      				"spec": {
      					"name": "ocs-operator"
      				}
      			}
      		}
      	}`),
			expected{
				message: "Installing OpenShift Data Foundation on IBM Cloud by using OperatorHub is not supported. You can install OpenShift Data Foundation by using the IBM Cloud add-on. For more information, see https://cloud.ibm.com/docs/openshift?topic=openshift-ocs-storage-prep.",
				allowed: false,
				code:    0,
			},
		},
		{
			"ValidateWithLabel",
			[]byte(`{
        		"request": {
        			"object": {
                "metadata":{
                    "labels":{
                       "cluster.ocs.openshift.io/ibm-odf-addon":"true"
                    }
                 },
        				"spec": {
        					"name": "ocs-operator"
        				}
        			}
        		}
        	}`),
			expected{
				message: "IBM ODF Addon may create the subscription",
				allowed: true,
				code:    0,
			},
		},
		{
			"ValidateBadRequest",
			[]byte(`{
          		"request": {
          		}`),
			expected{
				message: "",
				allowed: false,
				code:    http.StatusBadRequest,
			},
		},
		{
			"ValidateNilRequest",
			[]byte(`{
              }`),
			expected{
				message: "",
				allowed: false,
				code:    http.StatusBadRequest,
			},
		},
		{
			"ValidateUnmarshalError",
			[]byte(`{
              		"request": {
              		}
                }`),
			expected{
				message: "",
				allowed: false,
				code:    http.StatusBadRequest,
			},
		},
	}

	for _, tt := range tests {
		req := httptest.NewRequest(http.MethodPost, "/validate?timeout=2s", bytes.NewReader(tt.req))
		w := httptest.NewRecorder()

		Validate(w, req)
		res := w.Result()

		defer res.Body.Close()

		arReview := admissionv1.AdmissionReview{}
		if err := json.NewDecoder(res.Body).Decode(&arReview); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
		}

		if tt.name == "ValidateWithoutLabel" {
			assert.Equal(t, arReview.Response.Result.Message, tt.expected.message)
			assert.Equal(t, arReview.Response.Allowed, tt.expected.allowed)
		}
		if tt.name == "ValidateWithLabel" {
			assert.Equal(t, arReview.Response.Result.Message, tt.expected.message)
			assert.Equal(t, arReview.Response.Allowed, tt.expected.allowed)
		}
		if tt.name == "ValidateBadRequest" {
			assert.Equal(t, res.StatusCode, tt.expected.code)
		}
		if tt.name == "ValidateNilRequest" {
			assert.Equal(t, res.StatusCode, tt.expected.code)
		}
		if tt.name == "ValidateUnmarshalError" {
			assert.Equal(t, res.StatusCode, tt.expected.code)
		}
	}
}
