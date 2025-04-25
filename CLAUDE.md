# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Deployment Commands
- Deploy the homelab setup: `kubectl apply -k .`
- Deploy additional components: `helm install/upgrade [component] [chart] [options]`
- Check service status: `kubectl get pods -A` or `kubectl get svc -A`
- Apply single manifest: `kubectl apply -f manifest/filename.yaml`
- Check logs: `kubectl logs -n [namespace] [pod-name]`

## Code Style Guidelines
- YAML indentation: 2 spaces
- Maintain consistent resource naming conventions across manifests
- Group related resources in the same YAML file
- Always include descriptive comments for non-obvious configurations
- Add resource requests/limits for all containers
- Use templated secrets for sensitive information
- Organize Kubernetes resources with proper labels and annotations
- Document environment requirements in README.md

## Infrastructure Notes
- The project uses NFS-based persistent storage by default
- NodePort services are forwarded through systemd services
- GPU resources are virtualized with time-slicing
- Secret templates should never be committed with actual values