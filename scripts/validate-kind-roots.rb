#!/usr/bin/env ruby

require "set"
require "yaml"

ROOTS = {
  "clusters/kind/shared.yaml" => {
    name: "k8s-playground-kind-root",
    path: "clusters/kind/apps"
  },
  "clusters/kind/application.yaml" => {
    name: "k8s-playground-kind-application-root",
    path: "clusters/kind/application/apps"
  },
  "clusters/kind/observability.yaml" => {
    name: "k8s-playground-kind-observability-root",
    path: "clusters/kind/observability/apps"
  }
}.freeze

EXPECTED_CHILDREN = {
  "clusters/kind/apps" => Set.new(%w[
    argocd-config
    argocd-repositories
    cert-manager
    cert-manager-config
    gateway-api-crds
    minio
    observability-object-storage-config
  ]),
  "clusters/kind/application/apps" => Set.new(%w[
    alloy
    gateway-api-config
    istio-base
    istio-cni
    istio-ingressgateway
    istio-managementgateway
    istiod
    k8s-playground-service
    management-gateway-config
  ]),
  "clusters/kind/observability/apps" => Set.new(%w[
    grafana
    loki
    mimir
    tempo
  ])
}.freeze

repo_url = "https://github.com/mblayman/k8s-playground-argocd-apps.git"

ROOTS.each do |file, expected|
  root = YAML.load_file(file)
  abort "#{file} is not an Application" unless root["kind"] == "Application"
  abort "#{file} has the wrong name" unless root.dig("metadata", "name") == expected[:name]
  abort "#{file} has the wrong source repository" unless root.dig("spec", "source", "repoURL") == repo_url
  abort "#{file} has the wrong source path" unless root.dig("spec", "source", "path") == expected[:path]
  abort "#{file} must remain in the default project" unless root.dig("spec", "project") == "default"
end

all_children = Set.new

EXPECTED_CHILDREN.each do |directory, expected_names|
  resources = Dir.glob("#{directory}/*.yaml").map { |file| [file, YAML.load_file(file)] }
  applications = resources.select { |_file, resource| resource["kind"] == "Application" }
  actual_names = Set.new(applications.map { |_file, resource| resource.dig("metadata", "name") })
  abort "#{directory} child Applications differ: expected #{expected_names.to_a.sort}, got #{actual_names.to_a.sort}" unless actual_names == expected_names

  duplicate_names = actual_names & all_children
  abort "Child Application names appear in multiple roots: #{duplicate_names.to_a.sort}" unless duplicate_names.empty?
  all_children.merge(actual_names)

  expected_project = directory == "clusters/kind/observability/apps" ? "observability" : "default"
  applications.each do |file, application|
    abort "#{file} must use project #{expected_project}" unless application.dig("spec", "project") == expected_project
    abort "#{file} must be created in argocd" unless application.dig("metadata", "namespace") == "argocd"
  end
end

project_file = "clusters/kind/apps/observability-project.yaml"
project = YAML.load_file(project_file)
abort "#{project_file} is not the observability AppProject" unless project["kind"] == "AppProject" && project.dig("metadata", "name") == "observability"
abort "Observability project source restriction is missing" unless project.dig("spec", "sourceRepos") == ["https://github.com/mblayman/k8s-playground-platform-config.git"]
abort "Observability project destination restriction is missing" unless project.dig("spec", "destinations") == [{"server" => "https://kubernetes.default.svc", "namespace" => "observability"}]

puts "Validated three kind roots and #{all_children.length} uniquely owned child Applications."
