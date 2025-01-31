#!/usr/bin/env bash

set -o errexit

REPO_ROOT=$(git rev-parse --show-toplevel)
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
NGINX_VERSION=1.12.1

echo '>>> Installing NGINX Ingress'
helm upgrade -i nginx-ingress stable/nginx-ingress --version=${NGINX_VERSION} \
--wait \
--namespace ingress-nginx \
--set controller.stats.enabled=true \
--set controller.metrics.enabled=true \
--set controller.podAnnotations."prometheus\.io/scrape"=true \
--set controller.podAnnotations."prometheus\.io/port"=10254 \
--set controller.service.type=NodePort

kubectl -n ingress-nginx patch deployment/nginx-ingress-controller \
--type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--annotations-prefix=custom.ingress.kubernetes.io"}]'

kubectl -n ingress-nginx rollout status deployment/nginx-ingress-controller
kubectl -n ingress-nginx get all

echo '>>> Loading Flagger image'
kind load docker-image test/flagger:latest

echo '>>> Installing Flagger'
helm install ${REPO_ROOT}/charts/flagger \
--name flagger \
--namespace ingress-nginx \
--set prometheus.install=true \
--set ingressAnnotationsPrefix="custom.ingress.kubernetes.io" \
--set meshProvider=nginx \
--set crd.create=false

kubectl -n ingress-nginx set image deployment/flagger flagger=test/flagger:latest

kubectl -n ingress-nginx rollout status deployment/flagger
kubectl -n ingress-nginx rollout status deployment/flagger-prometheus

