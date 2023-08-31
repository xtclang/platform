<template>
  <q-page class="flex flex-center">
    <div class="row">
      <h1 class="col-12 text-brown-3 text-center text-h2">
        Welcome to Ecstasy Cloud
      </h1>
      <div class="col-12 text-center" v-if="!userStore.hasUser">
        To deploy modules and run applications you need to log in
      </div>
    </div>
  </q-page>
</template>

<script>
import { defineComponent } from "vue";
import { useUserStore } from "stores/user-store";

export default defineComponent({
  name: "IndexPage",

  setup() {
    const userStore = useUserStore();

    return {
      userStore,
    };
  },
});
</script>