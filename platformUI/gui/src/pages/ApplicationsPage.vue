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
        <q-toolbar class="text-primary">
          <q-toolbar-title> Registered applications </q-toolbar-title>
          <q-btn
            round
            dense
            icon="app_registration"
            @click="showUploadDialog = true"
          >
            <q-tooltip class="bg-secondary text-bold">
              Register new application!
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
                  {{ domain }}
                </q-item-section>
              </q-item>
            </q-item-section>

            <q-item-section>
              <q-item>
                <q-item-section avatar>
                  <q-icon name="extension" color="brown-12" size="lg" />
                </q-item-section>
                <q-item-section>
                  {{ currentWebApp.moduleName }}
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
                      :label="
                        currentWebApp.hostName + ':' + currentWebApp.httpPort
                      "
                      class="text-lowercase"
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
                      :label="
                        currentWebApp.hostName + ':' + currentWebApp.httpsPort
                      "
                      class="text-lowercase"
                    />
                  </q-item-section>
                </q-item>
              </q-list>
            </q-item-section>

            <q-item-section side>
              <div class="text-primary q-gutter-xs" style="min-width: 20%">
                <q-btn
                  class="gt-xs module-action"
                  size="12px"
                  flat
                  dense
                  round
                  icon="play_circle"
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
                  @click="deleteModule(name)"
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
  </q-page>
</template>

<script>
import { defineComponent, onBeforeMount, ref, watch } from "vue";
import { useUserStore } from "stores/user-store";
import { useWebAppStore } from "stores/webapp-store";
import { useQuasar } from "quasar";

export default defineComponent({
  name: "IndexPage",

  setup() {
    const $q = useQuasar();

    const userStore = useUserStore();
    const webAppStore = useWebAppStore();
    const showUploadDialog = ref(false);
    const fileToUpload = ref(null);
    const resolveOnUpload = ref(false);

    onBeforeMount(() => {
      if (userStore.hasUser) {
        webAppStore.updateWebApps();
      }
      if (process.env.DEV) {
        console.log(`DEV MODE: Add mock user`);
        userStore.user = "Mock User";

        console.log(`DEV MODE: Add mock data`);
        webAppStore.webAppsJSON = {
          $type: "ListMap<String, common.model2.WebAppInfo>",
          welcome: {
            moduleName: "welcome.examples.org",
            domain: "welcome",
            hostName: "xtc-platform.xqiz.it",
            bindAddr: "xtc-platform.xqiz.it",
            httpPort: 8100,
            httpsPort: 8101,
          },
        };

        console.log(`DEV MODE: enhance the mock data`);
        webAppStore.enhance();

        console.log(webAppStore.webAppsJSON);
      }
    });

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
      webAppStore,
    };
  },
});
</script>

<style lang="sass">

.module-action.disabled
    color: silver
</style>