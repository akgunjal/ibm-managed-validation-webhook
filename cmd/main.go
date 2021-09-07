/*******************************************************************************
 * IBM Confidential
 * OCO Source Materials
 * IBM Cloud Container Service, 5737-D43
 * (C) Copyright IBM Corp. 2021 All Rights Reserved.
 * The source code for this program is not  published or otherwise divested of
 * its trade secrets, irrespective of what has been deposited with
 * the U.S. Copyright Office.
 ******************************************************************************/

// Package main ...
package main

import (
	"flag"
	"io/ioutil"
	"net"

	"crypto/tls"
	"crypto/x509"
	"net/http"
	"os"

	validatewebhook "github.ibm.com/alchemy-containers/managed-storage-validation-webhooks/webhook"

	klog "k8s.io/klog/v2"
	"k8s.io/klog/v2/klogr"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
)

var log = logf.Log.WithName("handler")

var (
	listenAddress = flag.String("listen", "0.0.0.0", "listen address")
	listenPort    = flag.String("port", "5000", "port to listen on")
	tlsKey        = flag.String("tlskey", "", "TLS Key for TLS")
	tlsCert       = flag.String("tlscert", "", "TLS Certificate")
	caCert        = flag.String("cacert", "", "CA Cert file")
)

func main() {
	flag.Parse()
	klog.SetOutput(os.Stdout)

	logf.SetLogger(klogr.New())

	log.Info("HTTP server running at", "listen", net.JoinHostPort(*listenAddress, *listenPort))

	http.HandleFunc("/validate", validatewebhook.Validate)

	server := &http.Server{
		Addr: net.JoinHostPort(*listenAddress, *listenPort),
	}

	cafile, err := ioutil.ReadFile(*caCert)
	if err != nil {
		log.Error(err, "Couldn't read CA cert file")
		os.Exit(1)
	}
	certpool := x509.NewCertPool()
	certpool.AppendCertsFromPEM(cafile)

	server.TLSConfig = &tls.Config{
		RootCAs:    certpool,
		MinVersion: tls.VersionTLS12,
	}
	log.Error(server.ListenAndServeTLS(*tlsCert, *tlsKey), "Error serving TLS")
}
