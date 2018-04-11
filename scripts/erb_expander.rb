require "fileutils"
require "json"
require "yaml"

$: << File.dirname(__FILE__)
require "template_evaluation_context.rb"

deployment_mf, vcap_dir, job_name = *ARGV

job_mf = File.join(vcap_dir, "jobs-src", job_name, "job.MF")
release_job = YAML.load_file(job_mf)
context = {}

# create template evaluation context
context['default_properties'] = {}
release_job['properties'].each do |name, value|
  context['default_properties'][name] = value['default']
end

deployment = YAML.load_file(deployment_mf)
jobs = deployment['instance_groups'][0]['jobs']
job = jobs.select { |j| j['name'] == release_job['name'] }.first
context['job_properties'] = job['properties']
puts context.to_json

renderer = ERBRenderer.new(TemplateEvaluationContext.new(context))

puts "Expand monit template"
src_path = File.join(File.dirname(job_mf), "monit")
dst_path = File.join(vcap_dir, "jobs", job_name, "monit")
FileUtils.mkdir_p(File.dirname(dst_path))
renderer.render(src_path, dst_path)

dst_path = File.join(vcap_dir, "monit", "job", "0000_#{job_name}.monitrc")
FileUtils.mkdir_p(File.dirname(dst_path))
renderer.render(src_path, dst_path)

release_job['templates'].each do |erb, file|
  puts "Expand #{erb} into #{file}"
  src_path = File.join(File.dirname(job_mf), "templates", erb)
  dst_path = File.join(vcap_dir, "jobs", job_name, file)
  FileUtils.mkdir_p(File.dirname(dst_path))
  renderer.render(src_path, dst_path)
  if file.start_with? "bin/"
    File.chmod(0755, dst_path)
  end
end
