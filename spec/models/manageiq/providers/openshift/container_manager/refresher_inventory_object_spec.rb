# instantiated at the end, for both classical and graph refresh
shared_examples "openshift refresher VCR tests" do
  let(:all_images_count) { 40 } # including /oapi/v1/images data
  let(:pod_images_count) { 12 } # only images mentioned by pods
  let(:images_managed_by_openshift_count) { 32 } # only images from /oapi/v1/images

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    # env vars for easier VCR recording, see test_objects_record.sh
    hostname = ENV["OPENSHIFT_MASTER_HOST"] || "host.example.com"
    token    = ENV["OPENSHIFT_MANAGEMENT_ADMIN_TOKEN"] || "theToken"

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => "OpenShiftProvider",
      :connection_configurations => [{:endpoint       => {:role              => :default,
                                                          :hostname          => hostname,
                                                          :port              => "8443",
                                                          :security_protocol => "ssl-without-validation"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )

    @user_tag = FactoryGirl.create(:classification_cost_center_with_tags).entries.first.tag
  end

  def normal_refresh
    VCR.use_cassette(described_class.name.underscore + '_inventory_object',
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do

      collector = ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager.new(@ems, @ems)
      # TODO(lsmola) figure out a way to pass collector info, probably via target
      persister = ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager.new(@ems)

      inventory = ::ManagerRefresh::Inventory.new(
        persister,
        collector,
        [ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager.new]
      )

      inventory.parse.persist!
    end
  end

  def full_refresh_test
    2.times do
      @ems.reload
      normal_refresh
      @ems.reload

      assert_counts
      assert_specific_container
      assert_specific_container_group
      assert_specific_container_node
      assert_specific_container_services
      assert_specific_container_image_registry
      assert_specific_container_project
      assert_specific_container_route
      assert_specific_container_build
      assert_specific_container_build_pod
      assert_specific_container_template
      assert_specific_container_service_instance
      assert_specific_used_container_image(:metadata => true)
      assert_specific_unused_container_image(:metadata => true, :archived => false)
    end
  end

  it "will perform a full refresh on openshift" do
    full_refresh_test
  end

  def base_inventory_counts
    {
      :container_group            => 58,
      :container_node             => 0,
      :container                  => 0,
      :container_port_config      => 0,
      :container_route            => 0,
      :container_project          => 18,
      :container_build            => 0,
      :container_build_pod        => 0,
      :container_template         => 188,
      :container_image            => 0,
      :container_service_class    => 183,
      :container_service_instance => 1,
      :container_service_plan     => 186,
      :openshift_container_image  => 0,
    }
  end

  def assert_counts
    assert_table_counts(base_inventory_counts)
  end

  def assert_table_counts(expected_table_counts)
    actual = {
      :container_group            => ContainerGroup.count,
      :container_node             => ContainerNode.count,
      :container                  => Container.count,
      :container_port_config      => ContainerPortConfig.count,
      :container_route            => ContainerRoute.count,
      :container_project          => ContainerProject.count,
      :container_build            => ContainerBuild.count,
      :container_build_pod        => ContainerBuildPod.count,
      :container_template         => ContainerTemplate.count,
      :container_image            => ContainerImage.count,
      :container_service_class    => ContainerServiceClass.count,
      :container_service_instance => ContainerServiceInstance.count,
      :container_service_plan     => ContainerServicePlan.count,
      :openshift_container_image  => ManageIQ::Providers::Openshift::ContainerManager::ContainerImage.count,
    }
    expect(actual).to match expected_table_counts
  end

  def assert_specific_container
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by(:name => "manageiq-backend-0")
    expect(@containergroup).to(
      have_attributes(
        :name           => "manageiq-backend-0",
        :restart_policy => "Always",
        :dns_policy     => "ClusterFirst",
        :phase          => "Running",
      )
    )

    # Check the relation to container node
    # TODO(lsmola) collect and test

    # Check the relation to containers
    # TODO(lsmola) collect and test

    expect(@containergroup.container_project).to eq(ContainerProject.find_by(:name => "miq-demo"))
    expect(@containergroup.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_node
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_services
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_image_registry
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by(:name => "default")
    expect(@container_pr).to(
      have_attributes(
        :name         => "default",
        :display_name => nil,
      )
    )

    expect(@container_pr.container_groups.count).to eq(3)
    expect(@container_pr.container_templates.count).to eq(0)
    expect(@container_pr.container_service_classes.count).to eq(0)
    expect(@container_pr.container_service_instances.count).to eq(1)
    expect(@container_pr.container_service_plans.count).to eq(0)
    expect(@container_pr.containers.count).to eq(0)
    expect(@container_pr.container_replicators.count).to eq(0)
    expect(@container_pr.container_routes.count).to eq(0)
    expect(@container_pr.container_services.count).to eq(0)
    expect(@container_pr.container_builds.count).to eq(0)
    expect(ContainerBuildPod.where(:namespace => @container_pr.name).count).to eq(0)
    expect(@container_pr.ext_management_system).to eq(@ems)

    @another_container_pr = ContainerProject.find_by(:name => "miq-demo")
    expect(@another_container_pr.container_groups.count).to eq(5)
    expect(@another_container_pr.container_templates.count).to eq(1)
    expect(@another_container_pr.container_service_classes.count).to eq(0)
    expect(@another_container_pr.container_service_instances.count).to eq(0)
    expect(@another_container_pr.container_service_plans.count).to eq(0)
    expect(@another_container_pr.containers.count).to eq(0)
    expect(@another_container_pr.container_replicators.count).to eq(0)
    expect(@another_container_pr.container_routes.count).to eq(0)
    expect(@another_container_pr.container_services.count).to eq(0)
    expect(@another_container_pr.container_builds.count).to eq(0)
    expect(ContainerBuildPod.where(:namespace => @another_container_pr.name).count).to eq(0)
    expect(@another_container_pr.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_route
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_build
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_build_pod
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_template
    @container_template = ContainerTemplate.find_by(:ems_ref => "d0d2324c-a16e-11e8-ba7e-d094660d31fb")
    expect(@container_template).to(
      have_attributes(
        :name             => "manageiq",
        :type             => "ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate",
        :resource_version => "33819516"
      )
    )

    expect(@container_template.ext_management_system).to eq(@ems)
    expect(@container_template.container_project).to eq(ContainerProject.find_by(:name => "miq-demo"))
    expect(@container_template.container_template_parameters.count).to eq(43)
    expect(@container_template.container_template_parameters.find_by(:name => "NAME")).to(
      have_attributes(
        :description    => "The name assigned to all of the frontend objects defined in this template.",
        :display_name   => "Name",
        :ems_created_on => nil,
        :value          => "manageiq",
        :generate       => nil,
        :from           => nil,
        :required       => true,
      )
    )
  end

  def assert_specific_container_service_instance
    @container_service_instance = ContainerServiceInstance.find_by(:name => "mariadb-persistent-qdkzt")
    expect(@container_service_instance).to(
      have_attributes(
        :name          => "mariadb-persistent-qdkzt",
        :ems_ref       => "76af97e3-5650-4583-ae85-27294677f88d",
        :generate_name => nil
      )
    )
    expect(@container_service_instance.extra["spec"]).not_to be_nil
    expect(@container_service_instance.extra["status"]).not_to be_nil

    # Relation to Project and ems
    expect(@container_service_instance.container_project).to eq(ContainerProject.find_by(:name => "default"))
    expect(@container_service_instance.ext_management_system).to eq(@ems)

    # Relation to ContainerServiceClass
    expect(@container_service_instance.container_service_class).to(
      have_attributes(
        :name => "mariadb-persistent"
      )
    )
    expect(@container_service_instance.container_service_class.extra["spec"]).not_to be_nil
    expect(@container_service_instance.container_service_class.extra["status"]).not_to be_nil
    expect(@container_service_instance.container_service_class.container_service_instances.count).to eq(1)
    expect(@container_service_instance.container_service_class.container_service_plans.count).to eq(1)
    expect(@container_service_instance.container_service_class).to(
      eq(@container_service_instance.container_service_plan.container_service_class)
    )

    # Relation to ContainerServicePlan
    expect(@container_service_instance.container_service_plan).to(
      have_attributes(
        :name        => "default",
        :description => "Default plan",
      )
    )
    expect(@container_service_instance.container_service_plan.extra["spec"]).not_to be_nil
    expect(@container_service_instance.container_service_plan.extra["status"]).not_to be_nil
    expect(@container_service_instance.container_service_plan.container_service_instances.count).to eq(1)
  end

  def assert_specific_unused_container_image(metadata:, archived:)
    # TODO(lsmola) collect and test
  end

  def assert_specific_used_container_image(metadata:)
    # TODO(lsmola) collect and test
  end
end

describe ManageIQ::Providers::Openshift::ContainerManager::Refresher do
  context "graph refresh" do
    before(:each) do
      stub_settings_merge(
        :ems_refresh => {:openshift => {:inventory_object_refresh => true}}
      )
    end

    [
      {:saver_strategy => "batch", :use_ar_object => true},
      {:saver_strategy => "batch", :use_ar_object => false}
    ].each do |saver_options|
      context "with #{saver_options}" do
        before(:each) do
          stub_settings_merge(
            :ems_refresh => {:openshift => {:inventory_collections => saver_options}}
          )
        end

        include_examples "openshift refresher VCR tests"
      end
    end
  end
end
