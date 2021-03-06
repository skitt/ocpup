# Get worker security group.
data "aws_security_group" "worker_sg" {
  vpc_id = data.aws_vpc.env_vpc.id

  filter {
    name   = "tag:kubernetes.io/cluster/${var.infra_id}"
    values = ["owned"]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.infra_id}-worker-sg"]
  }
}

# Add a rule for vxlan traffic for all workers.
resource "aws_security_group_rule" "worker_sg_vxlan_rule" {
  security_group_id        = data.aws_security_group.worker_sg.id
  source_security_group_id = data.aws_security_group.worker_sg.id
  from_port                = 4800
  protocol                 = "udp"
  to_port                  = 4800
  type                     = "ingress"
}


# Create a submariner agteway security group.
resource "aws_security_group" "submariner_gw_sg" {
  name   = "${var.infra_id}-submariner-gw-sg"
  vpc_id = data.aws_vpc.env_vpc.id

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0

    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4500
    protocol    = "UDP"
    to_port     = 4501
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 500
    protocol    = "UDP"
    to_port     = 501
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(map(
    "Name", "${var.infra_id}-submariner-gw-sg",
    "kubernetes.io/cluster/${var.infra_id}", "owned"
  ))
}
