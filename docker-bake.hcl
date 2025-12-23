variable "TAG" {
  default = "latest"
}

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAME" {
  default = "kokamkarsahil/openalgo"
}

group "default" {
  targets = ["openalgo"]
}

target "openalgo" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
  
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${TAG}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]

  labels = {
    "org.opencontainers.image.title"       = "OpenAlgo"
    "org.opencontainers.image.description" = "OpenAlgo Trading Platform - Optimized for Coolify/Dokploy"
    "org.opencontainers.image.source"      = "https://github.com/marketcalls/openalgo"
    "org.opencontainers.image.version"     = "${TAG}"
  }

  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}