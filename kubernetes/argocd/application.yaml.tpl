apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sandbox-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${repo_url}
    targetRevision: ${revision}
    path: kubernetes/demo
  destination:
    server: https://kubernetes.default.svc
    namespace: sandbox-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
