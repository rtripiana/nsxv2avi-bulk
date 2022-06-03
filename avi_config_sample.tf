provider "avi" {
  avi_username = "admin"
  avi_tenant = "admin"
  avi_password = "yourpassword"
  avi_controller= "10.1.0.100"
  avi_version= "21.1.3"
}

data "avi_applicationprofile" "system_http_profile" {
  name= "System-HTTP"
}

data "avi_tenant" "default_tenant" {
  name= "admin"
}

data "avi_cloud" "default_cloud" {
  name= "Default-Cloud"
}

data "avi_serviceenginegroup" "se_group" {
  name = "Default-Group"
}

data "avi_networkprofile" "system_tcp_profile" {
  name= "System-TCP-Proxy"
}

data "avi_sslprofile" "system_standard_sslprofile" {
  name= "System-Standard"
}

data "avi_vrfcontext" "global_vrf" {
  name= "global"
}

variable "vs_list" {
  description = "list of virtual services"
  type        = list(list(string))
  default     = [["matrix","neo","1.1.1.1","80","agents"]]
}

variable "pool_members_list" {
  description = "list of pool members"
  type        = list(list(string))
  default     = [["10.10.10.10","20.20.20.20"]]
}

resource "avi_vsvip" "vsvip_addr" {
    count = length(var.vs_list) 
    name= var.vs_list[count.index][1] 
    cloud_ref= "${data.avi_cloud.default_cloud.id}"
    vip {
        vip_id= "${count.index}"
        ip_address {
            type= "V4"
            addr= var.vs_list[count.index][2] 
        }
    }
}

resource "avi_pool" "pool" {
  count = length(var.vs_list) 
  name= var.vs_list[count.index][4]  
  enabled= false
  tenant_ref= "${data.avi_tenant.default_tenant.id}"
  cloud_ref= "${data.avi_cloud.default_cloud.id}"
  dynamic "servers" {
    for_each= var.pool_members_list[count.index]
    content {
      ip {
        type= "V4"
        addr= servers.value
      }
      port= 8080
    }
  }
}

resource "avi_virtualservice" "vs" {
  count = length(var.vs_list)
  name= var.vs_list[count.index][0]
  enabled= false
  pool_ref= "${avi_pool.pool[count.index].id}"
  tenant_ref= "${data.avi_tenant.default_tenant.id}"
  cloud_ref= "${data.avi_cloud.default_cloud.id}"
  application_profile_ref= "${data.avi_applicationprofile.system_http_profile.id}"
  network_profile_ref = "${data.avi_networkprofile.system_tcp_profile.id}"
  vsvip_ref = "${avi_vsvip.vsvip_addr[count.index].id}"
  services {
    port= var.vs_list[count.index][3]
    enable_ssl= true
  }
  cloud_type = "CLOUD_VCENTER"
  se_group_ref= "${data.avi_serviceenginegroup.se_group.id}"
  vrf_context_ref= "${data.avi_vrfcontext.global_vrf.id}"
}