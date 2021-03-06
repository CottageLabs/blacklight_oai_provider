require 'rails/generators'

class BlacklightOaiProviderGenerator < Rails::Generators::Base
  argument :model_name, type: :string, default: "SolrDocument"
  argument :controller_name, type: :string, default: "CatalogController"

  def inject_solr_document_extension
    file_path = "app/models/#{model_name.underscore}.rb"
    return unless File.exist? file_path

    inject_into_file file_path, after: "include Blacklight::Solr::Document" do
      "\n  use_extension Blacklight::Document::DublinCore\n"
    end

    inject_into_file file_path, after: "include Blacklight::Solr::Document" do
      "\n  include BlacklightOaiProvider::SolrDocumentBehavior"
    end
  end

  def inject_catalog_controller_extension
    file_path = "app/controllers/#{controller_name.underscore}.rb"
    return unless File.exist? file_path

    inject_into_file file_path, after: "include Blacklight::Catalog" do
      "\n  include BlacklightOaiProvider::CatalogControllerBehavior\n"
    end

    inject_into_file file_path, after: "include Hydra::Controller::ControllerBehavior" do
      "\n  include BlacklightOaiProvider::CatalogControllerBehavior\n"
    end
  end

  def inject_route_concern
    file_path = "config/routes.rb"
    return unless File.exist? file_path

    inject_into_file file_path, after: "Rails.application.routes.draw do" do
      "\n  concern :oai_provider, BlacklightOaiProvider::Routes::Provider.new\n"
    end

    inject_into_file file_path, after: /resource :catalog,+ (.*)do$/ do
      "\n    concerns :oai_provider\n"
    end
  end
end
