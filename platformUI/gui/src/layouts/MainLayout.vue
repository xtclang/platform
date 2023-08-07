<template>
  <q-layout view="hHh lpR fFf" class="bg-grey-1">
    <q-header elevated class="bg-white text-grey-8" height-hint="64">
      <q-toolbar class="GNL__toolbar">
        <q-btn
          flat
          dense
          round
          @click="toggleLeftDrawer"
          aria-label="Menu"
          icon="menu"
          class="q-mr-sm text-brown-12"
        />

        <q-toolbar-title
          v-if="$q.screen.gt.xs"
          shrink
          class="row items-center no-wrap"
          @click="$router.push('/')"
        >
          <q-avatar square>
            <img src="~assets/logo.png" />
          </q-avatar>

          <span class="q-ml-md GNL__logo-name text-h4"
            ><span class="text-white">ECSTASY </span>
            <span class="text-secondary"><small>CLOUD</small></span></span
          >
        </q-toolbar-title>

        <q-space />

        <q-space />

        <div class="q-gutter-sm row items-center no-wrap text-white">
          <q-btn
            class="bg-secondary"
            flat
            v-if="!userStore.hasUser"
            @click="userStore.logIn()"
          >
            Log in
          </q-btn>

          <q-btn-dropdown color="secondary" v-if="userStore.hasUser">
            <template v-slot:label>
              <div class="row items-center no-wrap">
                <q-avatar size="26px">
                  <img src="~assets/avatar.jpg" />
                </q-avatar>
                <div class="text-center q-ml-md">{{ userStore.user }}</div>
              </div>
            </template>
            <q-list>
              <q-item clickable v-close-popup>
                <q-item-section>
                  <q-item-label>Account</q-item-label>
                </q-item-section>
              </q-item>

              <q-item clickable v-close-popup @click="userStore.logOut()">
                <q-item-section>
                  <q-item-label>Log out</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
        </div>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      class="bg-white"
      :width="280"
    >
      <q-scroll-area class="fit">
        <q-list>
          <q-expansion-item
            default-opened
            expand-separator
            icon="memory"
            label="Hosting"
            header-class="bg-brown-1 text-primary"
          >
            <q-list padding>
              <q-item
                class="GNL__drawer-item"
                v-ripple
                v-for="link in links1"
                :key="link.text"
                clickable
                :to="link.location"
              >
                <q-item-section avatar>
                  <q-icon :name="link.icon" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ link.text }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-expansion-item>

          <q-expansion-item
            default-opened
            expand-separator
            icon="summarize"
            label="Reports"
            header-class="bg-brown-1 text-primary"
          >
            <q-list padding>
              <q-item
                class="GNL__drawer-item"
                v-ripple
                v-for="link in links2"
                :key="link.text"
                clickable
              >
                <q-item-section avatar>
                  <q-icon :name="link.icon" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ link.text }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-expansion-item>

          <q-list padding class="text-grey-8">
            <q-item
              class="GNL__drawer-item"
              v-ripple
              v-for="link in links3"
              :key="link.text"
              clickable
            >
              <q-item-section>
                <q-item-label
                  >{{ link.text }} <q-icon v-if="link.icon" :name="link.icon"
                /></q-item-label>
              </q-item-section>
            </q-item>

            <div class="q-mt-md">
              <div class="flex flex-center q-gutter-xs">
                <a
                  class="GNL__drawer-footer-link"
                  href="javascript:void(0)"
                  aria-label="Privacy"
                  >Privacy</a
                >
                <span> · </span>
                <a
                  class="GNL__drawer-footer-link"
                  href="javascript:void(0)"
                  aria-label="Terms"
                  >Terms</a
                >
                <span> · </span>
                <a
                  class="GNL__drawer-footer-link"
                  href="javascript:void(0)"
                  aria-label="About"
                  >About Google</a
                >
              </div>
            </div>
          </q-list>
        </q-list>
      </q-scroll-area>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script>
import { ref, onMounted } from "vue";
import { useUserStore } from "stores/user-store";

export default {
  name: "MainLayout",

  setup() {
    const leftDrawerOpen = ref(false);
    const search = ref("");
    const showAdvanced = ref(false);
    const showDateOptions = ref(false);
    const exactPhrase = ref("");
    const hasWords = ref("");
    const excludeWords = ref("");
    const byWebsite = ref("");
    const byDate = ref("Any time");

    const userStore = useUserStore();

    function onClear() {
      exactPhrase.value = "";
      hasWords.value = "";
      excludeWords.value = "";
      byWebsite.value = "";
      byDate.value = "Any time";
    }

    function changeDate(option) {
      byDate.value = option;
      showDateOptions.value = false;
    }

    function toggleLeftDrawer() {
      leftDrawerOpen.value = !leftDrawerOpen.value;
    }

    onMounted(() => {
      userStore.updateUser();
    });

    return {
      leftDrawerOpen,
      search,
      showAdvanced,
      showDateOptions,
      exactPhrase,
      hasWords,
      excludeWords,
      byWebsite,
      byDate,
      userStore,

      links1: [
        { icon: "extension", text: "Modules", location: { name: "modules" } },
        {
          icon: "web_asset",
          text: "Applications",
          location: { name: "applications" },
        },
      ],
      links2: [
        { icon: "space_dashboard", text: "Dashboard 1" },
        { icon: "space_dashboard", text: "Dashboard 2" },
      ],
      links3: [
        { icon: "", text: "Send feedback" },
        { icon: "open_in_new", text: "Help" },
      ],

      onClear,
      changeDate,
      toggleLeftDrawer,
    };
  },
};
</script>

<style lang="sass">

.q-router-link--exact-active
  background-color: $amber-1

.GNL

  &__toolbar
    height: 64px
    background-color: $primary

    .q-toolbar__title
      cursor: pointer

  &__toolbar-input
    width: 55%

  &__logo-name
    font-family: 'Kodchasan', sans-serif
    color: #fff


  &__drawer-footer-link
    color: white
    text-decoration: none
    font-weight: 500
    font-size: .75rem

    &:hover
      color: #000
</style>
