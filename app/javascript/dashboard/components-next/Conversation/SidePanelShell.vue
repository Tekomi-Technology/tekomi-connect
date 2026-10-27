<template>
  <div
    class="bg-n-surface-2 h-full overflow-hidden flex-col fixed top-0 z-40 w-full max-w-sm ltr:right-0 rtl:left-0 xl:static xl:w-[320px] xl:min-w-[320px] 2xl:min-w-[360px] 2xl:w-[360px] shadow-xl xl:shadow-none"
  >
    <!-- Fixed width keeps the content from reflowing while the shell animates its width. -->
    <div
      class="flex flex-col flex-1 h-full min-h-0 w-screen max-w-sm shrink-0 xl:w-[320px] xl:max-w-none 2xl:w-[360px] ltr:border-l rtl:border-r border-n-weak"
    >
      <slot />
    </div>
  </div>
</template>
