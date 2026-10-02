<script setup>
import TodayQueueCard from '../cards/TodayQueueCard.vue';
import SlaGaugeCard from '../cards/SlaGaugeCard.vue';
import ResolutionRingCard from '../cards/ResolutionRingCard.vue';
import TrafficCard from '../cards/TrafficCard.vue';
import ChannelBreakdownCard from '../cards/ChannelBreakdownCard.vue';
import ActivityFeedCard from '../cards/ActivityFeedCard.vue';
import NeedsAttentionList from '../NeedsAttentionList.vue';

defineProps({
  data: { type: Object, required: true },
  groupBy: { type: String, required: true },
});
</script>

<template>
  <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <TodayQueueCard :live="data.live" class="lg:col-span-5" />
    <SlaGaugeCard :sla="data.sla" class="lg:col-span-4" />
    <ResolutionRingCard
      :summary="data.summary"
      :live="data.live"
      class="lg:col-span-3"
    />
    <TrafficCard
      :timeseries="data.timeseries"
      :group-by="groupBy"
      class="lg:col-span-8"
    />
    <ChannelBreakdownCard :channels="data.channels" class="lg:col-span-4" />
    <div class="min-w-0 lg:col-span-8">
      <NeedsAttentionList />
    </div>
    <ActivityFeedCard :events="data.activity" class="lg:col-span-4" />
  </div>
</template>
