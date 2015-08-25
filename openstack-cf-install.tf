provider "openstack" {
  auth_url = "${var.auth_url}"
  tenant_name = "${var.tenant_name}"
  user_name = "${var.username}"
  password = "${var.password}"
}

resource "openstack_networking_network_v2" "internal_net" {
  region = "${var.region}"
  name = "internal-net"
  admin_state_up = "true"
  tenant_id = "${var.tenant_id}"
}

resource "openstack_networking_network_v2" "lb_net" {
  region = "${var.region}"
  name = "lb-net"
  admin_state_up = "true"
  tenant_id = "${var.tenant_id}"
}

resource "openstack_networking_network_v2" "internal_net_docker_services" {
  region = "${var.region}"
  name = "internal-net-docker-services"
  admin_state_up = "true"
  tenant_id = "${var.tenant_id}"
}

resource "openstack_networking_network_v2" "internal_net_logsearch" {
  region = "${var.region}"
  name = "internal-net-logsearch"
  admin_state_up = "true"
  tenant_id = "${var.tenant_id}"
}

resource "openstack_networking_subnet_v2" "cf_subnet" {
  name = "cf-subnet"
  region = "${var.region}"
  network_id = "${openstack_networking_network_v2.internal_net.id}"
  cidr = "${var.network}.2.0/24"
  ip_version = 4
  tenant_id = "${var.tenant_id}"
  enable_dhcp = "true"
  dns_nameservers = ["${var.dns1}","${var.dns2}"]
}

resource "openstack_networking_subnet_v2" "lb_subnet" {
  name = "lb-subnet"
  region = "${var.region}"
  network_id = "${openstack_networking_network_v2.lb_net.id}"
  cidr = "${var.network}.0.0/24"
  ip_version = 4
  tenant_id = "${var.tenant_id}"
  enable_dhcp = "true"
  dns_nameservers = ["${var.dns1}","${var.dns2}"]
}

resource "openstack_networking_subnet_v2" "docker_services_subnet" {
  name = "docker-services-subnet"
  region = "${var.region}"
  network_id = "${openstack_networking_network_v2.internal_net_docker_services.id}"
  cidr = "${var.network}.5.0/24"
  ip_version = 4
  tenant_id = "${var.tenant_id}"
  enable_dhcp = "true"
  dns_nameservers = ["${var.dns1}","${var.dns2}"]
}

resource "openstack_networking_subnet_v2" "logsearch_subnet" {
  name = "logsearch-subnet"
  region = "${var.region}"
  network_id = "${openstack_networking_network_v2.internal_net_logsearch.id}"
  cidr = "${var.network}.7.0/24"
  ip_version = 4
  tenant_id = "${var.tenant_id}"
  enable_dhcp = "true"
  dns_nameservers = ["8.8.4.4","8.8.8.8"]
}

output "internal_network" {
  value = "${openstack_networking_subnet_v2.cf_subnet.id}"
}

resource "openstack_networking_router_v2" "router" {
  name = "router"
  region = "${var.region}"
  admin_state_up = "true"
  external_gateway = "${var.network_external_id}"
  tenant_id = "${var.tenant_id}"
}

output "router_id" {
  value = "${openstack_networking_router_v2.router.id}"
}

resource "openstack_networking_router_interface_v2" "int-ext-interface" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.cf_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "int-ext-docker-services-interface" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.docker_services_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "int-ext-lb-interface" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.lb_subnet.id}"
}

resource "openstack_networking_router_interface_v2" "int-ext-logsearch-interface" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.router.id}"
  subnet_id = "${openstack_networking_subnet_v2.logsearch_subnet.id}"
}

resource "openstack_compute_keypair_v2" "keypair" {
  name = "bastion-keypair-${var.tenant_name}"
  public_key = "${file(var.public_key_path)}"
  region = "${var.region}"
}

resource "openstack_compute_secgroup_v2" "bastion" {
  name = "bastion-${var.tenant_name}"
  description = "Bastion Security groups"
  region = "${var.region}"

  rule {
    ip_protocol = "tcp"
    from_port = "22"
    to_port = "22"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "icmp"
    from_port = "-1"
    to_port = "-1"
    cidr = "0.0.0.0/0"
  }

}

resource "openstack_compute_secgroup_v2" "cf" {
  name = "cf"
  description = "Cloud Foundry Security groups"
  region = "${var.region}"

  rule {
    ip_protocol = "tcp"
    from_port = "22"
    to_port = "22"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "80"
    to_port = "80"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "443"
    to_port = "443"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "4443"
    to_port = "4443"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "4222"
    to_port = "25777"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "icmp"
    from_port = "-1"
    to_port = "-1"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "icmp"
    from_port = "-1"
    to_port = "-1"
    self = true
  }

  rule {
    ip_protocol = "tcp"
    from_port = "1"
    to_port = "65535"
    self = true
  }

  rule {
    ip_protocol = "udp"
    from_port = "1"
    to_port = "65535"
    self = true
  }

}

output "cf_sg" {
  value = "${openstack_compute_secgroup_v2.cf.name}"
}

output "cf_sg_id" {
  value = "${openstack_compute_secgroup_v2.cf.id}"
}

resource "openstack_networking_floatingip_v2" "cf_fp" {
  region = "${var.region}"
  pool = "${var.floating_ip_pool}"
}


resource "openstack_networking_floatingip_v2" "bastion_fp" {
  region = "${var.region}"
  pool = "${var.floating_ip_pool}"
}


resource "openstack_compute_instance_v2" "bastion" {
  name = "bastion"
  image_name = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  region = "${var.region}"
  key_pair = "${openstack_compute_keypair_v2.keypair.name}"
  security_groups = [ "${openstack_compute_secgroup_v2.bastion.name}" ]
  floating_ip = "${openstack_networking_floatingip_v2.bastion_fp.address}"

  network {
    uuid = "${openstack_networking_network_v2.internal_net.id}"
  }

}

output "cf_api" {
  value = "api.run.${openstack_networking_floatingip_v2.cf_fp.address}.xip.io"
}

output "bastion_ip" {
  value = "${openstack_compute_instance_v2.bastion.floating_ip}"
}

output "username" {
  value = "${var.username}"
}

output "password" {
  value = "${var.password}"
}

output "tenant_name" {
  value = "${var.tenant_name}"
}

output "auth_url" {
  value = "${var.auth_url}"
}

output "region" {
  value = "${var.region}"
}

output "internal_network_id" {
  value = "${openstack_networking_network_v2.internal_net.id}"
}

output "network" {
  value = "${var.network}"
}

output "cf_fp_address" {
  value = "${openstack_networking_floatingip_v2.cf_fp.address}"
}

output "cf_size" {
  value = "${var.cf_size}"
}

output "cf_boshworkspace_version" {
  value = "${var.cf_boshworkspace_version}"
}

output "cf_domain" {
  value = "${var.cf_domain}"
}

output "cf_subnet_cidr" {
  value = "${openstack_networking_subnet_v2.cf_subnet.cidr}"
}

output "docker_subnet" {
  value = "${openstack_networking_network_v2.internal_net_docker_services.id}"
}

output "logsearch_subnet" {
  value = "${openstack_networking_network_v2.internal_net_logsearch.id}"
}

output "install_docker_services" {
  value = "${var.install_docker_services}"
}

output "install_logsearch" {
  value = "${var.install_logsearch}"
}

output "docker_subnet_cidr" {
  value = "${openstack_networking_subnet_v2.docker_services_subnet.cidr}"
}

output "lb_subnet" {
  value = "${openstack_networking_subnet_v2.lb_subnet.id}"
}

output "lb_net" {
  value = "${openstack_networking_network_v2.lb_net.id}"
}

output "lb_subnet_cidr" {
  value = "${openstack_networking_subnet_v2.lb_subnet.cidr}"
}

output "key_path" {
  value = "${var.key_path}"
}

output "cf_release_version" {
	value = "${var.cf_release_version}"
}

output "http_proxy" {
  value = "${var.http_proxy}"
}

output "https_proxy" {
  value = "${var.https_proxy}"
}

output "debug" {
  value = "${var.debug}"
}

output "backbone_z1_count" { value = "${lookup(var.backbone_z1_count, var.deployment_size)}" }
output "api_z1_count"      { value = "${lookup(var.api_z1_count,      var.deployment_size)}" }
output "services_z1_count" { value = "${lookup(var.services_z1_count, var.deployment_size)}" }
output "health_z1_count"   { value = "${lookup(var.health_z1_count,   var.deployment_size)}" }
output "runner_z1_count"   { value = "${lookup(var.runner_z1_count,   var.deployment_size)}" }
output "backbone_z2_count" { value = "${lookup(var.backbone_z2_count, var.deployment_size)}" }
output "api_z2_count"      { value = "${lookup(var.api_z2_count,      var.deployment_size)}" }
output "services_z2_count" { value = "${lookup(var.services_z2_count, var.deployment_size)}" }
output "health_z2_count"   { value = "${lookup(var.health_z2_count,   var.deployment_size)}" }
output "runner_z2_count"   { value = "${lookup(var.runner_z2_count,   var.deployment_size)}" }

output "private_cf_domains" {
  value = "${var.private_cf_domains}"
}
output "additional_cf_sg_allows" {
  value = "${var.additional_cf_sg_allow_1},${var.additional_cf_sg_allow_2},${var.additional_cf_sg_allow_3},${var.additional_cf_sg_allow_4},${var.additional_cf_sg_allow_5},${openstack_networking_subnet_v2.docker_services_subnet.cidr},${openstack_networking_subnet_v2.cf_subnet.cidr},${openstack_networking_subnet_v2.lb_subnet.cidr},${openstack_networking_floatingip_v2.cf_fp.address}"
}

output "backbone_resource_pool"        { value = "${var.backbone_resource_pool}" }
output "data_resource_pool"            { value = "${var.data_resource_pool}" }
output "public_haproxy_resource_pool"  { value = "${var.public_haproxy_resource_pool}" }
output "private_haproxy_resource_pool" { value = "${var.private_haproxy_resource_pool}" }
output "api_resource_pool"             { value = "${var.api_resource_pool}" }
output "services_resource_pool"        { value = "${var.services_resource_pool}" }
output "health_resource_pool"          { value = "${var.health_resource_pool}" }
output "runner_resource_pool"          { value = "${var.runner_resource_pool}" }

output "dns1" {
  value = "${var.dns1}"
}
output "dns2" {
  value = "${var.dns2}"
}

output "docker_boshworkspace_version" {
  value = "${var.docker_boshworkspace_version}"
}

output "os_timeout" {
  value = "${var.os_timeout}"
}

output "offline_java_buildpack" {
  value = "${var.offline_java_buildpack}"
}

output "ntp_servers" {
  value = "${var.ntp_servers}"
}

