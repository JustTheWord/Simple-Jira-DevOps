"""
Simple Jira DevOps - Deployment Model
-------------------------------------
This diagram shows:
 - GitLab as the source repo
 - A GitLab CI/CD Pipeline that runs tests, SonarQube analysis, and builds/pushes images
 - A Container Registry holding built images
 - A Webhook Server that receives deployment triggers
 - A Docker Compose host that runs the microservices (NotificationService, SimpleJira, Frontend)
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.gcp.compute import ComputeEngine
from diagrams.gcp.database import SQL
from diagrams.onprem.vcs import Gitlab
from diagrams.onprem.ci import GitlabCI
from diagrams.onprem.client import User
from diagrams.onprem.container import Docker
from diagrams.custom import Custom

# Define the diagram
with Diagram("Deployment Model", show=False, direction="TB"):
    # User
    developer = User("Developer")
    
    # GitLab setup
    gitlab_repo = Gitlab("GitLab Repo")
    pipeline = GitlabCI("GitLab CI/CD Pipeline")
    
    # Custom SonarQube and Docker Registry nodes
    sonarqube = Custom("SonarQube Analysis", "./resources/onprem/monitoring/sonarqube.png")
    registry = Custom("Container Registry", "./resources/onprem/container/registry.png")
    
    # GCP Deployment cluster
    with Cluster("Google Cloud Platform"):
        webhook_srv = ComputeEngine("Webhook Server")
        postgresql = SQL("PostgreSQL Instance")
        
        # Application services cluster
        with Cluster("Docker Compose Services"):
            notification_svc = Docker("NotificationService")
            simple_jira_svc = Docker("SimpleJira")
            frontend_svc = Docker("Frontend")
    
    # Workflow connections
    developer >> Edge(label="push code") >> gitlab_repo >> pipeline
    pipeline >> sonarqube
    pipeline >> Edge(label="push images") >> registry
    pipeline >> Edge(label="triggers webhook") >> webhook_srv
    webhook_srv >> Edge(label="pull image from registry") >> registry
    webhook_srv >> Edge(label="docker-compose pull & up") >> [notification_svc, simple_jira_svc, frontend_svc]
    simple_jira_svc >> Edge(label="connects to") >> postgresql

