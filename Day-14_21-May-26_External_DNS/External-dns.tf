##############################################
# ExternalDNS IAM Role (for Pod Identity)
##############################################
resource "aws_iam_role" "externaldns_role" {
  name = "${local.name}-externaldns-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

##############################################
# Attach AWS Managed Route53 Full Access
##############################################
resource "aws_iam_role_policy_attachment" "externaldns_managed_policy" {
  role       = aws_iam_role.externaldns_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

##############################################
# Output
##############################################
output "externaldns_role_arn" {
  value = aws_iam_role.externaldns_role.arn
}

# ---------------

##############################################
# ExternalDNS Pod Identity Association
##############################################
resource "aws_eks_pod_identity_association" "externaldns" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.externaldns_role.arn
}

##############################################
# Output
##############################################
output "externaldns_pod_identity_association_id" {
  value = aws_eks_pod_identity_association.externaldns.id
}

# --------------------------

##############################################
# Discover latest ExternalDNS addon version
##############################################
data "aws_eks_addon_version" "externaldns_latest" {
  addon_name         = "external-dns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

##############################################
# Install ExternalDNS Add-on
##############################################
resource "aws_eks_addon" "externaldns" {
  depends_on = [
    aws_iam_role.externaldns_role,
    aws_eks_pod_identity_association.externaldns,
    aws_eks_addon.podidentity,
    aws_eks_node_group.private_nodes
  ]  
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "external-dns"
  addon_version               = data.aws_eks_addon_version.externaldns_latest.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = aws_iam_role.externaldns_role.arn

  tags = {
    Component   = "ExternalDNS"
    ManagedBy   = "Terraform"
    Project     = local.name
  }
}

##############################################
# Outputs
##############################################
output "externaldns_addon_version" {
  value = aws_eks_addon.externaldns.addon_version
}

output "externaldns_addon_arn" {
  value = aws_eks_addon.externaldns.arn
}

output "externaldns_addon_id" {
  value = aws_eks_addon.externaldns.id
}