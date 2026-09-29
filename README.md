# flecto-example-terraform

A live demo of [Flecto](https://github.com/myselfsiddharth/Flecto) reviewing a
Terraform plan on a pull request.

**→ [PR #1 — the dangerous one](https://github.com/myselfsiddharth/flecto-example-terraform/pull/1)**
· ❌ 6 errors, check fails

**→ [PR #2 — an ordinary change](https://github.com/myselfsiddharth/flecto-example-terraform/pull/2)**
· ✅ no findings, check passes

Both run the same gate. The second one matters as much as the first: a check
that fires on everything gets uninstalled in a week.

---

## What this repository is

A deliberately small, safe, dummy AWS stack: a security group, an S3 bucket with
public access blocked, and an IAM role scoped to that one bucket.

Nothing is ever applied. The provider uses mock credentials with every
validation skipped and there is no backend, so `terraform plan` runs in CI purely
to produce a plan JSON. That plan is the point.

## The whole setup

[`.github/workflows/flecto.yml`](.github/workflows/flecto.yml), in full:

```yaml
- run: |
    terraform plan -out=tf.plan
    terraform show -json tf.plan > plan.json

- uses: myselfsiddharth/Flecto/.github/actions/flecto-pr-risk@v4.1.0
  with:
    terraform-plan: plan.json
    fail-on: error
```

Flecto never invokes `terraform` itself — it reads the JSON `terraform show`
already produced. Nothing extra has to exist on the runner, and no credentials
reach Flecto.

## The demo pull request

The PR looks like a small, reasonable change. Its description says it is about
letting a partner upload files. What it actually does:

1. **Opens the web security group to the internet** — `10.0.0.0/8` becomes
   `0.0.0.0/0`
2. **Turns off the bucket's public-access protection** — all four `block_*`
   flags flipped to `false`
3. **Widens the IAM policy to a wildcard** — `s3:GetObject`/`s3:PutObject` on one
   bucket becomes `s3:*` on `*`

Three lines of diff, spread across three resources, in a plan that is a few
hundred lines long. That is the review this tool exists for.

Flecto fails the check and posts one comment naming all three:

```
❌ Check failing — 30 changes in 1 file — 0 changed, 30 added, 0 removed.
Policy: 6 errors.

aws_security_group.web.ingress[0].cidr_blocks[0]
  terraform-security-group-open-ingress
  Security group ingress will accept traffic from the whole internet
  (0.0.0.0/0). Restrict the source to a known CIDR, a prefix list, or
  another security group.

aws_s3_bucket_public_access_block.uploads.block_public_acls        (+3 more)
  terraform-s3-public-access-block-disabled
  S3 public access block is being turned off or removed.

aws_iam_role_policy.app.policy
  terraform-iam-wildcard
  IAM policy grants a wildcard action or resource ("*").
```

Meanwhile [PR #2](https://github.com/myselfsiddharth/flecto-example-terraform/pull/2)
adds two tags to a bucket and reports **✅ Check passing — Policy: no findings**.

## A note on what this demo does not show

The `terraform` pack also catches **destroyed and replaced resources** — a
database about to be dropped, an EBS volume about to vanish. Those rules fire on
`removed` actions, which only appear in a plan when Terraform has **existing
state** to compare against.

This repository has no state, so every resource shows as `create` and those rules
stay quiet. That is a property of the demo, not a limitation of Flecto — in a
real repository with a backend, a plan that replaces a database produces:

> Terraform will destroy a stateful resource. Its data does not survive. Take a
> final snapshot, or add a `prevent_destroy` lifecycle block, before applying.

See **[Terraform plans](https://github.com/myselfsiddharth/Flecto/blob/main/docs/terraform.md)**
for the full rule list.

## Try it yourself

```bash
git clone https://github.com/myselfsiddharth/flecto-example-terraform
cd flecto-example-terraform
terraform init -backend=false
terraform plan -out=tf.plan
terraform show -json tf.plan > plan.json
npx --yes flecto@4 plan plan.json --fail-on error
```

---

MIT. Part of [Flecto](https://github.com/myselfsiddharth/Flecto).
