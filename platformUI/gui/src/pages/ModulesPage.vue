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
          <q-toolbar-title> Installed modules </q-toolbar-title>
          <q-btn
            round
            dense
            icon="cloud_upload"
            @click="showUploadDialog = true"
          >
            <q-tooltip class="bg-secondary text-bold">
              Install new module!
            </q-tooltip>
          </q-btn>
        </q-toolbar>
      </q-card-section>

      <q-card-section>
        <q-list flat separator>
          <q-item
            v-for="(currentModule, name) in moduleStore.modules"
            :key="name"
          >
            <q-item-section avatar top>
              <q-icon name="extension" color="brown-12" size="34px" />
            </q-item-section>

            <q-item-section top class="col-3 gt-sm">
              <q-item-label caption v-if="currentModule.isWebModule">
                <q-badge color="secondary">WebApp</q-badge>
              </q-item-label>
              <q-item-label class="q-mt-sm">
                {{ currentModule.name }}
              </q-item-label>
            </q-item-section>

            <q-item-section top>
              <q-expansion-item
                expand-separator
                :icon="currentModule.displayInfo.deps.icon"
                :header-class="currentModule.displayInfo.deps.displayClass"
                :expand-icon-class="currentModule.displayInfo.deps.displayClass"
                :label="currentModule.displayInfo.deps.displayText"
              >
                <q-list dense flat separator class="rounded-borders">
                  <q-item
                    v-for="dep in currentModule.dependentModules"
                    :key="dep.name"
                  >
                    <q-item-section avatar>
                      <q-icon
                        :color="dep.available ? 'positive' : 'negative'"
                        :name="dep.available ? 'verified' : 'warning'"
                        size="xs"
                      />
                    </q-item-section>

                    <q-item-section>
                      <q-item-label>{{ dep.name }}</q-item-label>
                      <q-item-label caption>{{
                        dep.qualifiedName
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-expansion-item>
            </q-item-section>

            <q-item-section top>
              <q-item v-if="!currentModule.displayInfo.issues.expandable">
                <q-item-section avatar>
                  <q-icon
                    color="primary"
                    :name="currentModule.displayInfo.issues.icon"
                    :class="currentModule.displayInfo.issues.displayClass"
                  />
                </q-item-section>
                <q-item-section
                  :class="currentModule.displayInfo.issues.displayClass"
                  >{{
                    currentModule.displayInfo.issues.displayText
                  }}</q-item-section
                >
              </q-item>

              <q-expansion-item
                v-if="currentModule.displayInfo.issues.expandable"
                expand-separator
                :icon="currentModule.displayInfo.issues.icon"
                :header-class="currentModule.displayInfo.issues.displayClass"
                :expand-icon-class="
                  currentModule.displayInfo.issues.displayClass
                "
                :label="currentModule.displayInfo.issues.displayText"
              >
                <q-list dense flat separator class="rounded-borders">
                  <q-item v-for="issue in currentModule.issues" :key="issue">
                    <q-item-section>
                      <q-item-label>{{ issue }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-expansion-item>
            </q-item-section>

            <q-item-section side>
              <div class="text-primary q-gutter-xs" style="min-width: 20%">
                <q-btn
                  class="gt-xs module-action"
                  size="12px"
                  flat
                  dense
                  round
                  icon="published_with_changes"
                  @click="moduleStore.resolveModule(name)"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Resolve
                  </q-tooltip>
                </q-btn>
                <q-btn
                  class="gt-xs module-action"
                  size="12px"
                  flat
                  dense
                  round
                  icon="app_registration"
                  :disable="
                    !currentModule.isWebModule ||
                    currentModule.issues.length > 0
                  "
                  @click="webAppDialog = { show: true, moduleName: name }"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Register application
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
                    Delete module
                  </q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card-section>
    </q-card>

    <q-dialog v-model="showUploadDialog" persistent>
      <q-card style="min-width: 350px">
        <q-bar class="bg-primary">
          <q-space />
          <q-btn class="text-white" dense flat icon="close" v-close-popup />
        </q-bar>

        <q-card-section>
          <div class="text-h6">Upload module(s)</div>
        </q-card-section>

        <q-card-section class="q-pt-none">
          <q-checkbox
            v-model="resolveOnUpload"
            label="Automatically resolve uploaded modules"
          />
          <q-uploader
            :url="moduleStore.uploadURL + '?resolve=' + resolveOnUpload"
            label="Select '.xtc' file(s) to upload"
            multiple
            batch
            accept=".xtc"
            :form-fields="[{ name: 'resolve', value: resolveOnUpload }]"
            @uploading="$q.loading.show()"
            @uploaded="moduleStore.updateModules()"
            @failed="$q.loading.hide()"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <q-dialog v-model="webAppDialog.show" persistent>
      <q-card style="min-width: 350px">
        <q-bar class="bg-primary">
          <q-space />
          <q-btn class="text-white" dense flat icon="close" v-close-popup />
        </q-bar>

        <q-card-section>
          <div class="text-h6">New web application</div>
        </q-card-section>

        <q-card-section class="q-pt-none">
          <q-input v-model="webAppDialog.moduleName" hint="Module" readonly>
            <template v-slot:prepend>
              <q-icon name="extension" />
            </template>
          </q-input>

          <q-input v-model="webAppDialog.domain" hint="Domain" autofocus>
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
    const showUploadDialog = ref(false);
    const webAppDialog = ref({ show: false, moduleName: undefined });
    const fileToUpload = ref(null);
    const resolveOnUpload = ref(false);

    onBeforeMount(() => {
      if (userStore.hasUser) {
        moduleStore.updateModules();
      }
    });

    watch(
      () => userStore.user,
      () => {
        if (userStore.user != undefined) {
          moduleStore.updateModules();
        }
      }
    );

    function registerWebApp() {
      webAppStore.registerWebApp(
        webAppDialog.value.domain,
        webAppDialog.value.moduleName,
        false
      );
    }

    function deleteModule(name) {
      $q.dialog({
        title: "Confirm",
        message: "Are you sure you want to delete module `" + name + "`?",
        cancel: true,
        persistent: true,
      }).onOk(() => {
        moduleStore.deleteModule(name);
      });
    }

    return {
      userStore,
      moduleStore,
      webAppStore,
      showUploadDialog,
      webAppDialog,
      fileToUpload,
      resolveOnUpload,
      registerWebApp,
      deleteModule,
    };
  },
});
</script>

<style lang="sass">

.module-action.disabled
    color: silver
</style>
