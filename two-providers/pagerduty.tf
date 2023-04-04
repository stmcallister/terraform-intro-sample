## see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs
provider "pagerduty" {
  token = "your_api_key_here"
}

## USERS
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/user
resource "pagerduty_user" "bart" {
  email       = "bart@foo.test"
  name        = "Bart Simpson"
  role        = "limited_user"
  description = "Spikey-haired boy"
  job_title   = "Rascal"
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/user
resource "pagerduty_user" "lisa" {
  email       = "lisa@foo.test"
  name        = "Lisa Simpson"
  role        = "admin"
  description = "The brains"
  job_title   = "Supreme Thinker"
}

# TEAMS
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/team
resource "pagerduty_team" "simpson" {
  name        = "Simpson"
  description = "Team of Simpsons"
}


# TEAM MEMBERSHIP
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/team_membership
resource "pagerduty_team_membership" "lisa" {
  user_id = pagerduty_user.lisa.id
  team_id = pagerduty_team.simpson.id
  role    = "manager"
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/team_membership
resource "pagerduty_team_membership" "bart" {
  user_id = pagerduty_user.bart.id
  team_id = pagerduty_team.simpson.id
  role    = "responder"
}


# escalation policy
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/escalation_policy
resource "pagerduty_escalation_policy" "checkout_service" {
  name      = "Checkout Service Escalation Policy"
  num_loops = 3

  rule {
    escalation_delay_in_minutes = 30
    target {
      type = "schedule_reference"
      id   = pagerduty_schedule.checkout_service.id
    }
  }
}

# SCHEDULE
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/schedule
resource "pagerduty_schedule" "checkout_service" {
  name      = "Checkout Service Schedule"
  time_zone = "America/Los_Angeles"

  layer {
    name                         = "Night Shift"
    start                        = "2022-10-27T20:00:00-08:00"
    rotation_virtual_start       = "2022-10-27T17:00:00-08:00"
    rotation_turn_length_seconds = 86400

    users = [
      pagerduty_user.lisa.id,
      pagerduty_user.bart.id
    ]

    restriction {
      type              = "daily_restriction"
      start_time_of_day = "07:00:00"
      duration_seconds  = 54000
    }
  }
}

# SERVICES
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service
resource "pagerduty_service" "api" {
  name              = "Checkout API"
  escalation_policy = pagerduty_escalation_policy.checkout_service.id
  alert_creation    = "create_alerts_and_incidents"
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service
resource "pagerduty_service" "db" {
  name              = "Checkout DB"
  escalation_policy = pagerduty_escalation_policy.checkout_service.id
  alert_creation    = "create_alerts_and_incidents"
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service
resource "pagerduty_service" "unrouted" {
  name              = "Checkout Unrouted"
  escalation_policy = pagerduty_escalation_policy.checkout_service.id
  alert_creation    = "create_alerts_and_incidents"

  auto_pause_notifications_parameters {
    enabled = true
    timeout = 900
  }
}

# SERVICE INTEGRATION
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/vendor
data "pagerduty_vendor" "cloudwatch" {
  name = "Cloudwatch"
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_integration
resource "pagerduty_service_integration" "cloudwatch" {
  name    = data.pagerduty_vendor.cloudwatch.name
  service = pagerduty_service.api.id
  vendor  = data.pagerduty_vendor.cloudwatch.id
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/data-sources/vendor
data "pagerduty_vendor" "datadog" {
  name = "Datadog"
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_integration
resource "pagerduty_service_integration" "datadog" {
  name    = data.pagerduty_vendor.datadog.name
  service = pagerduty_service.api.id
  vendor  = data.pagerduty_vendor.datadog.id
}

# BUSINESS SERVICE
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/business_service
resource "pagerduty_business_service" "api_business" {
  name = "API Business"
}

# SERVICE DEPENDENCY
# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency
resource "pagerduty_service_dependency" "api_service_dependency" {
  dependency {
    dependent_service {
      id   = pagerduty_business_service.api_business.id
      type = "business_service"
    }

    supporting_service {
      id   = pagerduty_service.api.id
      type = "service"
    }
  }
}

# see https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/service_dependency
resource "pagerduty_service_dependency" "api_db_service_dependency" {
  dependency {
    dependent_service {
      id   = pagerduty_business_service.api_business.id
      type = "business_service"
    }

    supporting_service {
      id   = pagerduty_service.db.id
      type = "service"
    }
  }
}