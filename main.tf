terraform {
  required_providers {
    google = {
        source  = "hashicorp/google"
        required_version = ">= 4.25.0"
    }
  }
}

# DB
resource "google_sql_database" "postgresql" {
    name     = "songs-db"
    project = "${var.project_id}"
    database_version = "POSTGRES_15"
    region = "${var.region}"
    settings {
        tier = "db-f1-micro"
    }
    deletion_protection = false
}

resource "google_sql_database" "postgresql_db" {
  name      = "songs-db"
  instance  = "${google_sql_database_instance.postgresql.name}"
}

resource "google_sql_user" "postgresql_user" {
  name     = "db-user"
  instance = "${google_sql_database_instance.postgresql.name}"
  password = "p@ssw0rd"
}