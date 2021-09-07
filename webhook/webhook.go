/*
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Package webhook ...
package webhook

import (
	"encoding/json"

	"net/http"

	v1alpha1 "github.com/operator-framework/api/pkg/operators/v1alpha1"
	admissionv1 "k8s.io/api/admission/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
)

var log = logf.Log.WithName("handler")

// Validate handler accepts or rejects based on request contents
func Validate(w http.ResponseWriter, r *http.Request) {
	arReview := admissionv1.AdmissionReview{}
	if err := json.NewDecoder(r.Body).Decode(&arReview); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	} else if arReview.Request == nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	raw := arReview.Request.Object.Raw

	sub := &v1alpha1.Subscription{}
	if err := json.Unmarshal(raw, &sub); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	arReview.Response = &admissionv1.AdmissionResponse{
		UID:     arReview.Request.UID,
		Allowed: true,
	}

	//Validate if subscription has required label
	if sub.Spec.Package == "ocs-operator" {
		labels := sub.GetLabels()
		_, okIbmAddon := labels["cluster.ocs.openshift.io/ibm-odf-addon"]
		if okIbmAddon {
			arReview.Response.Allowed = true
			arReview.Response.Result = &metav1.Status{
				Message: "IBM ODF Addon may create the subscription",
			}
			log.Info("Attempted ODF install via addon")
		} else {
			log.Info("Attempted to deploy ODF without using the IBM Addon")
			arReview.Response.Allowed = false
			arReview.Response.Result = &metav1.Status{
				Message: "Installing OpenShift Data Foundation on IBM Cloud by using OperatorHub is not supported. You can install OpenShift Data Foundation by using the IBM Cloud add-on. For more information, see https://cloud.ibm.com/docs/openshift?topic=openshift-ocs-storage-prep.",
			}
			log.Info("Attempted ODF install via Operator Hub")
		}
	}

	w.Header().Set("Content-Type", "application/json")
	err := json.NewEncoder(w).Encode(&arReview)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
}
