require 'spec_helper'
describe 'aix_lvm_facts' do
  context 'with default values for all parameters' do
    it { should contain_class('aix_lvm_facts') }
  end
end
