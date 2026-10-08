<script setup>
import guide from './content';
import RichText from './RichText.vue';

const sectionNumber = index => String(index + 1).padStart(2, '0');

const scrollToSection = id => {
  document
    .getElementById(`user-guide-${id}`)
    ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
};
</script>

<template>
  <section class="flex w-full h-full overflow-y-auto">
    <div class="flex w-full max-w-6xl gap-10 px-6 py-6 mx-auto">
      <nav class="sticky self-start hidden w-60 top-0 shrink-0 lg:block">
        <p
          class="mb-3 text-xs font-medium tracking-wide uppercase text-n-slate-10"
        >
          {{ $t('USER_GUIDE.CONTENTS') }}
        </p>
        <ul class="flex flex-col gap-1">
          <li v-for="(section, index) in guide.sections" :key="section.id">
            <button
              type="button"
              class="flex w-full gap-2 px-2 py-1.5 text-sm text-left rounded-lg text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
              @click="scrollToSection(section.id)"
            >
              <span class="font-medium text-n-teal-10">
                {{ sectionNumber(index) }}
              </span>
              <span>{{ section.title }}</span>
            </button>
          </li>
        </ul>
      </nav>

      <article class="flex flex-col flex-1 min-w-0 gap-10 pb-16">
        <header class="flex flex-col gap-2">
          <h1 class="text-2xl font-semibold text-n-slate-12">
            {{ $t('USER_GUIDE.HEADER') }}
          </h1>
          <p class="max-w-3xl mb-0 text-sm leading-6 text-n-slate-11">
            {{ guide.intro }}
          </p>
        </header>

        <section
          v-for="(section, index) in guide.sections"
          :id="`user-guide-${section.id}`"
          :key="section.id"
          class="flex flex-col max-w-3xl gap-4 scroll-mt-6"
        >
          <h2
            class="flex items-baseline gap-3 text-lg font-semibold text-n-slate-12"
          >
            <span class="text-sm font-medium text-n-teal-10">
              {{ sectionNumber(index) }}
            </span>
            {{ section.title }}
          </h2>

          <template
            v-for="(block, blockIndex) in section.blocks"
            :key="blockIndex"
          >
            <h3
              v-if="block.type === 'h3'"
              class="mt-2 text-base font-semibold text-n-slate-12"
            >
              {{ block.text }}
            </h3>

            <p
              v-else-if="block.type === 'p'"
              class="mb-0 text-sm leading-6 text-n-slate-11"
            >
              <RichText :text="block.text" />
            </p>

            <ol
              v-else-if="block.type === 'ol'"
              class="flex flex-col gap-2 mb-0 text-sm leading-6 list-decimal ps-5 text-n-slate-11 marker:text-n-teal-10"
            >
              <li v-for="(item, itemIndex) in block.items" :key="itemIndex">
                <RichText :text="item.text || item" />
                <ul
                  v-if="item.items"
                  class="flex flex-col gap-1 mt-1 mb-0 list-disc ps-5"
                >
                  <li
                    v-for="(child, childIndex) in item.items"
                    :key="childIndex"
                  >
                    <RichText :text="child" />
                  </li>
                </ul>
              </li>
            </ol>

            <div
              v-else-if="block.type === 'table'"
              class="overflow-x-auto border rounded-xl border-n-weak"
            >
              <table class="w-full text-sm text-left">
                <thead class="bg-n-alpha-2">
                  <tr>
                    <th
                      v-for="heading in block.head"
                      :key="heading"
                      class="px-3 py-2 font-medium text-n-slate-12"
                    >
                      {{ heading }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(row, rowIndex) in block.rows"
                    :key="rowIndex"
                    class="border-t border-n-weak"
                  >
                    <td
                      v-for="(cell, cellIndex) in row"
                      :key="cellIndex"
                      class="px-3 py-2 align-top text-n-slate-11"
                      :class="{
                        'font-medium text-n-slate-12': cellIndex === 0,
                      }"
                    >
                      {{ cell }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <figure
              v-else-if="block.type === 'image'"
              class="p-4 m-0 bg-white border rounded-xl border-n-weak"
            >
              <img :src="block.src" :alt="block.alt" class="w-full h-auto" />
            </figure>
          </template>
        </section>
      </article>
    </div>
  </section>
</template>
