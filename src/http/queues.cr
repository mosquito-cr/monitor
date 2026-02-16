get "/queues" do |env|
  queues = Mosquito::Api::Queue.all
  Mosquito::InspectWeb.render "queues.html.ecr"
end
