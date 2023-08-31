<template>
  <q-page>
    <q-banner class="bg-negative text-white q-ma-xl" v-if="!userStore.hasUser">
      Please to log in to see your deployed modules
    </q-banner>

    <q-card
      flat
      bordered
      class="rounded-borders q-ma-lg"
      v-if="userStore.hasUser"
    >
      <q-card-section>
        <q-toolbar class="text-primary q-gutter-md">
          <q-toolbar-title> Registered applications </q-toolbar-title>
          <q-btn
            round
            dense
            icon="refresh"
            @click="webAppStore.updateWebApps()"
          >
            <q-tooltip class="bg-secondary text-bold"> Refresh </q-tooltip>
          </q-btn>
          <q-btn
            round
            dense
            icon="app_registration"
            @click="showAddRegistrationDialog()"
          >
            <q-tooltip class="bg-secondary text-bold">
              Register new application
            </q-tooltip>
          </q-btn>
        </q-toolbar>
      </q-card-section>

      <q-card-section>
        <q-list flat separator>
          <q-item
            v-for="(currentWebApp, domain) in webAppStore.webApps"
            :key="domain"
          >
            <q-item-section>
              <q-item>
                <q-item-section avatar>
                  <q-icon name="web" color="brown-12" size="lg" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ domain }}</q-item-label>
                  <q-item-label caption>
                    <q-icon name="extension" color="brown-12" size="xs" />
                    <span class="q-ml-xs">{{ currentWebApp.moduleName }}</span>
                  </q-item-label>
                </q-item-section>
              </q-item>
            </q-item-section>

            <q-item-section top>
              <q-list dense flat>
                <q-item>
                  <q-item-section>
                    <q-btn
                      flat
                      color="primary"
                      icon="lock_open"
                      align="left"
                      class="text-lowercase"
                      :label="`${currentWebApp.hostName}:${currentWebApp.httpPort}`"
                      :href="`http://${currentWebApp.hostName}:${currentWebApp.httpPort}`"
                      :target="domain"
                    />
                  </q-item-section>
                </q-item>
                <q-item>
                  <q-item-section>
                    <q-btn
                      flat
                      color="primary"
                      icon="https"
                      align="left"
                      class="text-lowercase"
                      :label="`${currentWebApp.hostName}:${currentWebApp.httpsPort}`"
                      :href="`https://${currentWebApp.hostName}:${currentWebApp.httpsPort}`"
                      :target="domain"
                    />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-item-section>

            <q-item-section>
              <q-item>
                <q-item-section avatar>
                  <q-icon
                    :name="currentWebApp.displayInfo.icon"
                    :color="currentWebApp.displayInfo.displayColor"
                    size="lg"
                  />
                </q-item-section>
                <q-item-section>
                  {{ currentWebApp.displayInfo.displayText }}
                </q-item-section>
              </q-item>
            </q-item-section>

            <q-item-section side>
              <div class="text-primary q-gutter-xs" style="min-width: 20%">
                <q-btn
                  v-if="currentWebApp.active"
                  class="gt-xs module-action text-negative"
                  size="12px"
                  flat
                  dense
                  round
                  icon="stop_circle"
                  @click="webAppStore.stopWebApp(domain)"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Stop
                  </q-tooltip>
                </q-btn>
                <q-btn
                  v-if="!currentWebApp.active"
                  class="gt-xs module-action text-positive"
                  size="12px"
                  flat
                  dense
                  round
                  icon="play_circle"
                  @click="webAppStore.startWebApp(domain)"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Start
                  </q-tooltip>
                </q-btn>
                <q-btn
                  class="gt-xs module-action"
                  size="12px"
                  flat
                  dense
                  round
                  icon="delete"
                  @click="unregisterWebApp(domain)"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Unregister
                  </q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card-section>
    </q-card>

    <q-dialog v-model="newAppDialog.show" persistent>
      <q-card style="min-width: 350px">
        <q-bar class="bg-primary">
          <q-space />
          <q-btn class="text-white" dense flat icon="close" v-close-popup />
        </q-bar>

        <q-card-section>
          <div class="text-h6">New web application</div>
        </q-card-section>

        <q-card-section class="q-pt-none">
          <q-select
            v-model="newAppDialog.moduleName"
            :options="moduleStore.webModuleNames"
            label="Module"
          >
            <template v-slot:prepend>
              <q-icon name="extension" />
            </template>
          </q-select>

          <q-input v-model="newAppDialog.domain" label="Domain" autofocus>
            <template v-slot:prepend>
              <q-icon name="web_asset" />
            </template>
          </q-input>
        </q-card-section>

        <q-card-actions align="right" class="text-primary">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            flat
            label="Register"
            v-close-popup
            @click="registerWebApp()"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script>
import { defineComponent, onBeforeMount, ref, watch } from "vue";
import { useUserStore } from "stores/user-store";
import { useModuleStore } from "stores/module-store";
import { useWebAppStore } from "stores/webapp-store";
import { useQuasar } from "quasar";

export default defineComponent({
  name: "IndexPage",

  setup() {
    const $q = useQuasar();

    const userStore = useUserStore();
    const moduleStore = useModuleStore();
    const webAppStore = useWebAppStore();
    const newAppDialog = ref({ show: false });

    onBeforeMount(() => {
      if (userStore.hasUser) {
        webAppStore.updateWebApps();
      }
    });

    function showAddRegistrationDialog() {
      moduleStore.updateModules();
      newAppDialog.value.show = true;
    }

    function registerWebApp() {
      webAppStore.registerWebApp(
        newAppDialog.value.domain,
        newAppDialog.value.moduleName,
        true
      );
    }

    function unregisterWebApp(domain) {
      $q.dialog({
        title: "Confirm",
        message:
          "Are you sure you want to remove the web application `" +
          domain +
          "`?",
        cancel: true,
        persistent: true,
      }).onOk(() => {
        webAppStore.unregisterWebApp(domain);
      });
    }

    watch(
      () => userStore.user,
      () => {
        if (userStore.user != undefined) {
          webAppStore.updateWebApps();
        }
      }
    );

    return {
      userStore,
      moduleStore,
      webAppStore,
      newAppDialog,
      showAddRegistrationDialog,
      registerWebApp,
      unregisterWebApp,
    };
  },
});
</script>

<style lang="sass">

.module-action.disabled
    color: silver
</style>