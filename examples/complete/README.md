# complete

The service provider and consumer use two VPCs in the same account. Healthy CLB/ALB backends across multiple zones support an Endpoint Service allowing only the current account, with automatic acceptance disabled. The consumer creates a multi-zone Endpoint in its VPC. After verifying the request, the service provider enables explicit approval. A PrivateZone in the same account binds only the consumer VPC and uses CNAME to point the business domain to the Endpoint domain.

This example provides same-account, multi-zone private access with manual connection approval and consumer private DNS.

Supply required variables.tf inputs in local terraform.tfvars. backends and consumer_subnets use zone IDs as keys and require at least two zones. Backends must cover consumer zones. Provide an unused IPv4 address belonging to each consumer subnet.

One Provider configuration manages the service, Endpoint, approval, and DNS resources with the current deployment identity. Supply AK/SK unchanged through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`. Set `consumer_account_id` to this identity's account ID, and supply backends, VPCs, subnets, and security groups owned by that account. The account allowlist permits connection requests; callers maintain the IAM permissions required to manage these resources.

The module source is `terraform-volcenginecc-modules/privatelink/volcenginecc`. Replace terraform commands with tofu when using OpenTofu. Ensure that the deployment identity can manage the service, Endpoint, approval, and PrivateZone resources:

1. With Terraform 1.5.7, run init/plan with approve_connection=false. After Apply, verify the Endpoint request and PendingAcceptance. DNS is created at this stage, but traffic is not yet enabled.
2. Verify the consumer account, VPC, Endpoint ID, and requested service. Set approve_connection=true, run plan/apply again, and verify Connected, business port access, and DNS inside the VPC.
3. Run a second Plan and review any drift before making further changes. Plan and apply changes to service_description, tags, connection_bps, or dns_ttl separately.
4. To revoke approval while retaining the Endpoint, set approve_connection=false and apply. Confirm that the connection is rejected or disconnected before approving it again.
5. After Destroy, verify an empty State and independently query the service, Endpoint, approval, PrivateZone, and record to confirm removal. External VPCs, backends, and security groups are outside this example's cleanup scope.

By default, the example uses a consumer PrivateZone CNAME visible only to its bound VPC. If a same-name Zone exists, manage DNS through another composition to avoid ownership by two States.

The caller must allow health checks in the Endpoint security group: IPv4 ingress ICMP from `100.64.0.0/10` (`port_start = -1`, `port_end = -1`), or IPv6 ingress ICMPv6 from `fd00:64::/32`, in addition to business port rules. Wait three minutes after initial acceptance before judging health. An unhealthy target can return NXDOMAIN even when the CNAME exists and the connection is Connected; verify every zone's ServiceStatus and DNS from the consumer VPC.

Native service DNS is optional: configure native_private_dns.name (only public type currently), add the TXT verification record from the services output to public authoritative DNS, and then enable verify. Enable enable_native_private_dns only after the cloud reports Verified. Verification is write-only and may cause second-Plan readback issues. Avoid domain conflicts with this example's CNAME Zone. Private native DNS type and wildcard names are not implemented.

Access control combines the explicit account allowlist, consumer security group, and backend listeners/authentication. The Provider does not expose a separate Endpoint Policy field; this example creates no security group rules or IAM policies. NLB backends are not supported by this example.
