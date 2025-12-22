variable "TAG" {
  default = "latest"
}

variable "REGISTRY" {
  default = "ghcr.io/kokamkarsahil"
}

variable "IMAGE_NAME" {
  default = "openalgo"
}

target "default" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${TAG}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]
}