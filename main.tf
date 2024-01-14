terraform {
  required_version = ">= 1.6"

  required_providers {
	google = ">= 5.10"
  }
}

# DB
resource "google_sql_database_instance" "song" {
    name     = "song"
    project = "${var.project_id}"
    database_version = "POSTGRES_15"
    region = "${var.region}"
    settings {
        tier = "db-f1-micro"
    }
    deletion_protection = false
}

# resource "google_sql_database" "postgresql_db" {
#   name      = "postgres"
#   instance  = "${google_sql_database_instance.song.name}"
# }

resource "google_sql_user" "postgresql_user" {
  name     = "postgres"
  instance = "${google_sql_database_instance.song.name}"
  password = "postgres"
}

resource "google_project_service" "sqladmin_api" {
  service            = "sqladmin.googleapis.com"
}

#cloud run
resource "google_cloud_run_v2_service" "gcp-lyrics-app" {
  name     = "gcp-lyrics-app"
  location = "${var.region}"

  template {
    containers {
      image = "gcr.io/${var.project_id}/app"

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.song.connection_name]
      }
    }
  }
  client     = "terraform"
  depends_on = [google_project_service.cloudrun_api, google_project_service.sqladmin_api]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_v2_service.gcp-lyrics-app.location
  project     = google_cloud_run_v2_service.gcp-lyrics-app.project
  service     = google_cloud_run_v2_service.gcp-lyrics-app.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_project_service" "cloudrun_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}
