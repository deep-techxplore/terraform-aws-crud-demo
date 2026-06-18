# deploy.tf
# The application-delivery half of the pipeline (STEP 7-10). The CI job builds the
# jar first (mvn clean package); Terraform then:
#   STEP 8  -> uploads that jar to the artifacts S3 bucket (aws_s3_object)
#   STEP 9  -> registers it as an Elastic Beanstalk application version
#   STEP 10 -> the EB environment (elasticbeanstalk.tf) points its version_label
#              at this version, which triggers the rolling deploy (STEP 11).

locals {
  # Content hash of the built jar. It changes ONLY when the compiled artifact
  # changes, which is the key to "Terraform knows which version is latest":
  #   - same code  -> same hash -> same object key + version name -> NO redeploy
  #   - new code   -> new hash  -> new object key + version name  -> redeploy
  #
  # Guarded with fileexists() so `terraform destroy` still evaluates even when the
  # jar isn't built (destroy deletes from state and doesn't need the file). During
  # a real apply the CI/local build always produces the jar, so the true hash is used.
  app_jar_hash = fileexists(var.app_jar_path) ? filemd5(var.app_jar_path) : "absent"
}

# STEP 8 — upload the jar. The hash is in the key so each distinct build is a
# distinct, immutable object (and old ones remain for rollback via versioning).
resource "aws_s3_object" "app_jar" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "app-versions/curd-${local.app_jar_hash}.jar"
  source = var.app_jar_path

  # etag = md5 lets Terraform detect drift if the object is changed out-of-band.
  etag = local.app_jar_hash
}

# STEP 9 — register the uploaded jar as an EB application version. The version
# name embeds the hash so it is unique per build and idempotent for re-runs.
resource "aws_elastic_beanstalk_application_version" "app" {
  name        = "curd-${local.app_jar_hash}"
  application = aws_elastic_beanstalk_application.app.name
  description = "Deployed by Terraform (jar md5 ${local.app_jar_hash})"
  bucket      = aws_s3_object.app_jar.bucket
  key         = aws_s3_object.app_jar.key
}
