terraform {
  required_providers {
    google = {
        source  = "hashicorp/google"
        required_version = ">= 4.25.0"
    }
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

resource "google_sql_database" "postgresql_db" {
  name      = "postgres"
  instance  = "${google_sql_database_instance.postgresql.name}"
}

resource "google_sql_user" "postgresql_user" {
  name     = "postgres"
  instance = "${google_sql_database_instance.postgresql.name}"
  password = "postgres"
}

resource "google_cloud_run_v2_service" "gcp-lyrics-app" {
  name     = "gcp-lyrics-app"
  location = "${var.region}"

  template {
    containers {
      image = "gcr.io/${var.project_id}/lyrics-app"

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
  depends_on = [google_project_service.secretmanager_api, google_project_service.cloudrun_api, google_project_service.sqladmin_api]
}