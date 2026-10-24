# GitHub and GitLab Integration

This directory contains documentation and integration components for connecting the AI-Powered Mobile DevOps Command Center with GitHub and GitLab.

## Purpose

The integration will help collect deployment and repository information to support incident investigation.

## Planned Features

* Retrieve deployment information.
* Identify recent commits associated with an incident.
* Collect relevant workflow or pipeline status.
* Provide deployment context to the incident investigation workflow.

## Security

* Use environment variables to store access tokens.
* Apply the principle of least privilege.
* Never commit access tokens, passwords, or other secrets.
