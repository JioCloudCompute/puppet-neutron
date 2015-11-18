require File.join(File.dirname(__FILE__), '..','..','..',
                  'puppet/provider/neutron')

Puppet::Type.type(:neutron_network).provide(
  :neutron,
  :parent => Puppet::Provider::Neutron
) do
  desc <<-EOT
    Neutron provider to manage neutron_network type.

    Assumes that the neutron service is configured on the same host.
  EOT

  commands :neutron => 'neutron'

  def self.neutron_type
    'net'
  end

  def self.instances
    existing_resources_as_hash.values.collect do |resource_hash|
      new(resource_hash)
    end
  end

  def self.prefetch(resources)
    @existing_resources = nil
  end

  def self.existing_resources_as_hash()
    @existing_resources ||= begin
      resources_hash = {}
      begin
        list_neutron_resources(neutron_type).each do |id|
          attrs = get_neutron_resource_attrs(neutron_type, id)
          resources_hash[attrs['name']] =
            {
              :ensure                    => :present,
              :name                      => attrs['name'],
              :id                        => attrs['id'],
              :admin_state_up            => attrs['admin_state_up'],
              :provider_network_type     => attrs['provider:network_type'],
              :provider_physical_network => attrs['provider:physical_network'],
              :provider_segmentation_id  => attrs['provider:segmentation_id'],
              :router_external           => attrs['router:external'],
              :shared                    => attrs['shared'],
              :tenant_id                 => attrs['tenant_id']
            }
        end
      rescue StandardError => e
        fail("Caught unexpected exception: #{e}: #{e.message}")
      end
      resources_hash
    end
  end

  def self.add_existing_resource(name, hash)
    unless @existing_resources.class == Hash
      fail("Cannot add to uninitialized resource hash")
    end
    @existing_resources[name]=hash
  end

  def add_existing_instance(name, hash)
    self.class.add_existing_resource(name, hash)
  end

  def existing_resource
    self.class.existing_resources_as_hash[resource[:name]] || {}
  end

  def exists?
    existing_resource[:ensure] == :present
  end

  def create
    network_opts = Array.new

    if @resource[:shared]
      network_opts << '--shared'
    end

    if @resource[:tenant_name]
      tenant_id = self.class.get_tenant_id(model.catalog,
                                           @resource[:tenant_name])
      network_opts << "--tenant_id=#{tenant_id}"
    elsif @resource[:tenant_id]
      network_opts << "--tenant_id=#{@resource[:tenant_id]}"
    end

    if @resource[:provider_network_type]
      network_opts << \
        "--provider:network_type=#{@resource[:provider_network_type]}"
    end

    if @resource[:provider_physical_network]
      network_opts << \
        "--provider:physical_network=#{@resource[:provider_physical_network]}"
    end

    if @resource[:provider_segmentation_id]
      network_opts << \
        "--provider:segmentation_id=#{@resource[:provider_segmentation_id]}"
    end

    if @resource[:router_external] and @resource[:router_external].casecmp("true")
      network_opts << "--router:external"
    end

    results = auth_neutron('net-create', '--format=shell',
                           network_opts, resource[:name])

    if results =~ /Created a new network:/
      attrs = self.class.parse_creation_output(results)
      add_existing_instance(
        resource[:name],
        {
          :ensure                    => :present,
          :name                      => resource[:name],
          :id                        => attrs['id'],
          :admin_state_up            => attrs['admin_state_up'],
          :provider_network_type     => attrs['provider:network_type'],
          :provider_physical_network => attrs['provider:physical_network'],
          :provider_segmentation_id  => attrs['provider:segmentation_id'],
          :router_external           => attrs['router:external'],
          :shared                    => attrs['shared'],
          :tenant_id                 => attrs['tenant_id'],
        }
      )
    else
      fail("did not get expected message on network creation, got #{results}")
    end
  end

  def destroy
    auth_neutron('net-delete', name)
    existing_resource[:ensure] = :absent
  end

  def id
    existing_resource[:id]
  end

  def admin_state_up
    existing_resource[:admin_state_up]
  end

  def admin_state_up=(value)
    auth_neutron('net-update', "--admin_state_up=#{value}", name)
  end

  def shared
    existing_resource[:shared]
  end

  def shared=(value)
    auth_neutron('net-update', "--shared=#{value}", name)
  end

  def router_external
    existing_resource[:router_external]
  end

  def router_external=(value)
    auth_neutron('net-update', "--router:external=#{value}", name)
  end

  def provider_network_type
    existing_resource[:provider_network_type]
  end

  def provider_physical_network
    existing_resource[:provider_physical_network]
  end

  def provider_segmentation_id
    existing_resource[:provider_segmentation_id]
  end

  def tenant_id
    existing_resource[:tenant_id]
  end

  [
   :provider_network_type,
   :provider_physical_network,
   :provider_segmentation_id,
   :tenant_id,
  ].each do |attr|
     define_method(attr.to_s + "=") do |value|
       fail("Property #{attr.to_s} does not support being updated")
     end
  end

end
