import { mount } from '@vue/test-utils';
import CampaignList from '../CampaignList.vue';

const CampaignCardStub = {
  name: 'CampaignCard',
  props: ['campaignId', 'title'],
  template: '<div class="campaign-card-stub">{{ title }}</div>',
};

const buildCampaigns = count =>
  Array.from({ length: count }, (_, index) => ({
    id: index + 1,
    title: `Campaign ${index + 1}`,
    message: 'message',
  }));

const mountList = campaigns =>
  mount(CampaignList, {
    props: { campaigns },
    global: { stubs: { CampaignCard: CampaignCardStub } },
  });

describe('CampaignList', () => {
  it('renders every campaign when there are fewer than one page worth', () => {
    const wrapper = mountList(buildCampaigns(5));

    expect(wrapper.findAllComponents(CampaignCardStub)).toHaveLength(5);
  });

  it('shows only the first page (25 items) when there are more campaigns than the page size', () => {
    const wrapper = mountList(buildCampaigns(30));

    const cards = wrapper.findAllComponents(CampaignCardStub);
    expect(cards).toHaveLength(25);
    expect(cards[0].props('title')).toBe('Campaign 1');
    expect(cards[24].props('title')).toBe('Campaign 25');
  });

  it('shows the remaining campaigns after navigating to the next page', async () => {
    const wrapper = mountList(buildCampaigns(30));

    // Pagination buttons render in order: first, prev, next, last (NextButton is
    // globally stubbed to a plain <button>, so we address them by position).
    const [, , nextPageButton] = wrapper.findAll('button');
    await nextPageButton.trigger('click');

    const cards = wrapper.findAllComponents(CampaignCardStub);
    expect(cards).toHaveLength(5);
    expect(cards[0].props('title')).toBe('Campaign 26');
  });

  it('resets back to the first page when the campaigns list changes', async () => {
    const wrapper = mountList(buildCampaigns(30));
    const [, , nextPageButton] = wrapper.findAll('button');
    await nextPageButton.trigger('click');
    expect(wrapper.findAllComponents(CampaignCardStub)[0].props('title')).toBe(
      'Campaign 26'
    );

    await wrapper.setProps({ campaigns: buildCampaigns(3) });

    const cards = wrapper.findAllComponents(CampaignCardStub);
    expect(cards).toHaveLength(3);
    expect(cards[0].props('title')).toBe('Campaign 1');
  });

  it('does not render the pagination footer when there are no campaigns', () => {
    const wrapper = mountList([]);

    expect(wrapper.find('footer').exists()).toBe(false);
  });
});
