# complete

The provider runs healthy CLB/ALB backends across multiple zones in its VPC and creates an Endpoint Service allowing only the specified consumer account, with automatic acceptance disabled. The consumer creates a multi-zone Endpoint in its VPC. After verifying the request, the provider enables explicit approval. A PrivateZone in the consumer account binds the consumer VPC and uses CNAME to point the business domain to the Endpoint domain.

This supports SaaS private access, communication across VPCs, and platform service delivery. On 2026-11-04, two zones, manual approval, DNS, and cleanup passed a retest across two VPCs in one account, after the required Endpoint ICMP health rule was added. Cross-account access was not tested. Only basic/complete directories are provided; their scenarios follow AWS VPC Endpoints and Alibaba Cloud PrivateLink without borrowing unsupported fields.

Supply required variables.tf inputs in local terraform.tfvars. backends and consumer_subnets use zone IDs as keys and require at least two zones. Backends must cover consumer zones. Provide an unused IPv4 address belonging to each consumer subnet.

For different accounts, service_profile and consumer_profile must identify independently configured local account profiles. Store credentials unchanged without decoding, and never put plaintext AK/SK in the repository. consumer_account_id must match consumer identity. Single-account tests may leave both profiles null and use environment credentials. Allowlist permission is distinct from IAM cross-account role permission; callers maintain their IAM policies.

The public module source is `terraform-volcenginecc-modules/privatelink/volcenginecc`. This draft is unpublished, so init requires Registry publication. Static validation replaces the source only in isolated copies to test the current code; it does not prove Registry consumption. OpenTofu 1.11.8 validation is static only, without a real cloud lifecycle. Replace terraform commands with tofu when using it. Subsequent cloud operations require corresponding deployment authorization:

1. With Terraform 1.5.7, run init/plan with approve_connection=false. After Apply, verify the Endpoint request and PendingAcceptance. DNS is created at this stage, but traffic is not yet enabled.
2. Verify the consumer account, VPC, Endpoint ID, and requested service. Set approve_connection=true, run plan/apply again, and verify Connected, business port access, and DNS inside the VPC.
3. The second Plan must show No changes. Update service_description, tags, connection_bps, or dns_ttl to test updates, then confirm No changes again.
4. Set approve_connection=false to test approval deletion/revocation. This may reject/disconnect the connection; it does not delete the Endpoint. Whether accepting again is allowed requires cloud verification.
5. After Destroy, verify an empty State and independently query the service, Endpoint, approval, PrivateZone, and record to confirm removal. External VPCs, backends, and security groups are outside this example's cleanup scope.

Terraform 1.5.7 and online Provider 0.0.73 tested the current local module in an isolated example copy: initial Apply, manual approval, two healthy zones, default/zone-domain and CNAME resolution, HTTP by hostname, the second Plan (No changes), and standard Destroy passed. The CNAME resolved both specified Endpoint IPs inside the consumer VPC and returned NXDOMAIN from the service VPC, as expected. Independent observation confirmed Rejected before Endpoint deletion and service deletion afterward. All temporary resources were removed. Registry module consumption remains unverified. The full update matrix in step 3, standalone revocation/reacceptance in step 4, and native TXT/cross-account branches remain unverified.

By default, the example uses a consumer PrivateZone CNAME visible only to its bound VPC; Zones are not shared across accounts. If a same-name Zone exists, manage DNS through another composition to avoid ownership by two States.

The caller must allow health checks in the Endpoint security group: IPv4 ingress ICMP from `100.64.0.0/10` (`port_start = -1`, `port_end = -1`), or IPv6 ingress ICMPv6 from `fd00:64::/32`, in addition to business port rules. Wait three minutes after initial acceptance before judging health. An unhealthy target can return NXDOMAIN even when the CNAME exists and the connection is Connected; verify every zone's ServiceStatus and DNS from the consumer VPC.

Native service DNS is optional: configure native_private_dns.name (only public type currently), add the TXT verification record from the services output to public authoritative DNS, and then enable verify. Enable enable_native_private_dns only after the cloud reports Verified. Verification is write-only and may cause second-Plan readback issues. Avoid domain conflicts with this example's CNAME Zone. Private native DNS type, wildcard names, and shared cross-account DNS Zones are not implemented.

Access policy combines the explicit account allowlist, consumer security group, and backend listeners/authentication. The Provider Schema has no AWS-style Endpoint Policy; this example creates no security group rules or IAM policies. NLB backends lack support confirmation in target-version documentation; if NLB is mandatory, obtain Provider support evidence first.
