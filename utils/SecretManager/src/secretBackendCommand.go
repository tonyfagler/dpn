package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"

	"secretBackend/src/awsSecretManager"
	"secretBackend/src/azureSecretManager"
)

func main() {

	secrets := readSecretInput()

	var output map[string]map[string]string
	switch cloud := os.Args[1]; cloud {
	case "aws":
		output = awsSecretManager.GetSecrets(os.Args[2], os.Args[3], secrets.Secrets)
	case "azure":
	 	output = azureSecretManager.GetSecrets(os.Args[2], secrets.Secrets)
	}

	fmt.Print(string(toJason(output)))
}

func toJason(secretData map[string]map[string]string) []byte {
	output, err := json.Marshal(secretData)
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not serialize res: %s", err)
		os.Exit(1)
	}
	return output
}

func readSecretInput() secretKeysPayload {
	data, err := ioutil.ReadAll(os.Stdin)

	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not read from stdin: %s", err)
		os.Exit(1)
	}

	secrets := secretKeysPayload{}
	json.Unmarshal(data, &secrets)
	return secrets
}

type secretKeysPayload struct {
	Secrets []string
	Version int
}