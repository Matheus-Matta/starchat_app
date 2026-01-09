<script setup>
import StackedChangelogCard from './StackedChangelogCard.vue';

const imageCards = {
  id: 'chatwoot-cosmos',
  title: 'Chatwoot Cosmos',
  meta_title: 'Chatwoot Cosmos',
  meta_description:
    'Watch how our latest feature can transform your workflow with powerful automation tools.',
  slug: 'chatwoot-cosmos',
  feature_image: 'https://www.starchats.com.br/images/cosmos/cosmos_thumbnail.jpg',
};

const handleReadMore = () => {
  console.log(`Read more: ${imageCards.title}`);
};

const handleDismiss = () => {
  console.log(`Dismissed: ${imageCards.title}`);
};

const handleImgClick = () => {
  console.log(`Card clicked: ${imageCards.title}`);
};
</script>

<template>
  <Story
    title="Components/ChangelogCard/StackedChangelogCard"
    :layout="{ type: 'grid', width: '260px' }"
  >
    <Variant title="Single Card - With Image">
      <div class="p-3 bg-n-solid-2 w-56">
        <StackedChangelogCard
          :card="imageCards"
          is-active
          :is-dismissing="false"
          @read-more="handleReadMore(imageCards)"
          @dismiss="handleDismiss(imageCards)"
          @img-click="handleImgClick(imageCards)"
        />
      </div>
    </Variant>
  </Story>
</template>
