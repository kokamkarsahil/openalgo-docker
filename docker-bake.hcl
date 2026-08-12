// OpenAlgo Docker Bake Configuration
// Used for multi-platform builds via GitHub Actions

variable "TAG" {
  default = "latest"
}

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAME" {
  default = "kokamkarsahil/openalgo"
}

variable "UPSTREAM_REPO" {
  default = "marketcalls/openalgo"
}

group "default" {
  targets = ["openalgo"]
}

target "openalgo" {
  context    = "."
  dockerfile = "Dockerfile"
  
  // Build for both AMD64 and ARM64
  platforms = ["linux/amd64", "linux/arm64"]
  
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${TAG}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]

  args = {
    UPSTREAM_REPO = "${UPSTREAM_REPO}"
  }

  labels = {
    "org.opencontainers.image.title"       = "OpenAlgo"
    "org.opencontainers.image.description" = "OpenAlgo Trading Platform - Optimized for Coolify/Dokploy"
    "org.opencontainers.image.source"      = "https://github.com/marketcalls/openalgo"
    "org.opencontainers.image.version"     = "${TAG}"
    "org.opencontainers.image.vendor"      = "OpenAlgo"
  }

  // GitHub Actions cache
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}