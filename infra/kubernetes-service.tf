resource "kubernetes_service" "journal_api" {
  metadata {
    name = "journal-api-service"
    annotations = {
      # 🛡️ THE SECURITY LINK: Attach your ACL certificate to the Load Balancer
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"         = aws_acm_certificate.api_cert.arn
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"        = "443"
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
      "service.beta.kubernetes.io/aws-load-balancer-type"             = "nlb" # optional, but recommended for modern setups
    }
  }
  spec {
    selector = { app = "journal-api" }
    type     = "LoadBalancer"
    port {
      name        = "https"
      port        = 443
      target_port = 8000
    }
    port {
      name        = "http"
      port        = 80
      target_port = 8000
    }
  }
  # 🔑 THIS IS THE KEY: 
  # Terraform now "knows" this service depends on EKS.
  # When you 'destroy', it will delete the Service FIRST, 
  # which removes the AWS Load Balancer automatically!
  depends_on = [module.eks]
}
