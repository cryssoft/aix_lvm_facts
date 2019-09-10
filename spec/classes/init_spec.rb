require 'spec_helper'
describe 'aix_vg_facts' do
  context 'with default values for all parameters' do
    it { should contain_class('aix_vg_facts') }
  end
end
