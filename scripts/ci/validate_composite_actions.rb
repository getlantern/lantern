# frozen_string_literal: true

require "yaml"

manifests = Dir[".github/actions/**/{action.yml,action.yaml}"].sort
abort "no composite action manifests found" if manifests.empty?

manifests.each do |path|
  action = YAML.safe_load(File.read(path), aliases: true, filename: path)
  abort "#{path}: manifest must be a mapping" unless action.is_a?(Hash)

  runs = action["runs"]
  unless runs.is_a?(Hash) && runs["using"] == "composite"
    abort "#{path}: runs.using must be composite"
  end

  steps = runs["steps"]
  abort "#{path}: runs.steps must not be empty" unless steps.is_a?(Array) && !steps.empty?

  steps.each_with_index do |step, index|
    label = "#{path}: runs.steps[#{index}]"
    abort "#{label} must be a mapping" unless step.is_a?(Hash)

    has_run = step.key?("run")
    has_uses = step.key?("uses")
    abort "#{label} must define exactly one of run or uses" unless has_run ^ has_uses

    if has_run && !step["shell"].is_a?(String)
      abort "#{label} must define shell for run"
    end
  end
end

puts "Validated #{manifests.length} composite action manifests"
