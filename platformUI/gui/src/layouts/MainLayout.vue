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
            @click="showSignInDialog"
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
          </q-list>
        </q-list>
      </q-scroll-area>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>

    <q-dialog v-model="signInDialog">
      <q-card square class="q-pa-none shadow-1">
        <q-card-section class="bg-primary">
          <h4 class="text-h5 text-white q-my-xs">Ecstasy Cloud Login</h4>
        </q-card-section>
        <q-card-section>
          <q-form class="q-gutter-md">
            <div>
              <q-input
                square
                filled
                autofocus
                v-model="account"
                label="account"
                @keyup.enter="signIn"
              />
            </div>
            <div>
              <q-input
                square
                filled
                v-model="password"
                label="password"
                :type="showPassword ? 'text' : 'password'"
                @keyup.enter="signIn"
              >
                <template v-slot:append>
                  <q-icon
                    :name="showPassword ? 'fas fa-eye' : 'fas fa-eye-slash'"
                    class="cursor-pointer"
                    size="xs"
                    @click="showPassword = !showPassword"
                  />
                </template>
              </q-input>
            </div>
          </q-form>
        </q-card-section>
        <q-card-actions class="q-px-md">
          <q-btn
            unelevated
            color="secondary"
            size="lg"
            class="full-width"
            label="Login"
            @click="signIn"
            @keyup.enter="signIn"
          />
        </q-card-actions>
        <q-card-section class="text-center q-pa-none">
          <p>Not registered? Create an Account</p>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-layout>
</template>

<script>
import { ref, onMounted } from "vue";
import { useUserStore } from "stores/user-store";

export default {
  name: "MainLayout",

  setup() {
    const leftDrawerOpen = ref(false);
    const signInDialog = ref(false);
    const userStore = useUserStore();
    const account = ref("");
    const password = ref("");
    const showPassword = ref(false);

    function toggleLeftDrawer() {
      leftDrawerOpen.value = !leftDrawerOpen.value;
    }

    function showSignInDialog() {
      account.value = "";
      password.value = "";
      signInDialog.value = true;
    }

    function hideSignInDialog() {
      signInDialog.value = false;
      account.value = "";
      password.value = "";
    }

    function signIn() {
      userStore.logIn(account.value, password.value, hideSignInDialog);
    }

    onMounted(() => {
      userStore.updateUser();
    });

    return {
      leftDrawerOpen,
      userStore,
      toggleLeftDrawer,
      signInDialog,
      showSignInDialog,
      signIn,
      account,
      password,
      showPassword,

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
