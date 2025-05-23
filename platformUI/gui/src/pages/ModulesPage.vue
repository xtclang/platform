<template>
  <q-page>
    <q-banner class="bg-negative text-white q-ma-xl" v-if="!userStore.hasUser">
      Please log in to see your deployed modules
    </q-banner>

    <q-card
      flat
      bordered
      class="rounded-borders q-ma-lg"
      v-if="userStore.hasUser"
    >
      <q-card-section>
        <q-toolbar class="text-primary q-gutter-md">
          <q-toolbar-title> Installed modules </q-toolbar-title>
          <q-btn
            round dense icon="refresh"
            @click="moduleStore.updateModules()"
          >
            <q-tooltip class="bg-secondary text-bold"> Refresh </q-tooltip>
          </q-btn>
          <q-btn
            round dense icon="cloud_upload"
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
            v-for="module in moduleStore.modules"
            :key="module.name"
          >
            <q-item-section avatar top>
              <q-icon v-if     ="module.kind=='Web'" name="wysiwyg"
                color="brown-12" size="34px"/>
              <q-icon v-else-if="module.kind=='Db'"  name="fa-solid fa-database"
                color="brown-12" size="34px"/>
              <q-icon v-else                               name="extension"
                color="brown-12" size="34px"/>
            </q-item-section>

            <q-item-section top class="col-3 gt-sm">
              <q-item-label caption v-if="module.kind=='Web'">
                <q-badge color="secondary">WebApp</q-badge>
              </q-item-label>
              <q-item-label caption v-else-if="module.kind=='Db'">
                <q-badge color="secondary">Database</q-badge>
              </q-item-label>
              <q-item-label class="q-mt-sm"> {{ simpleName(module.name) }} </q-item-label>
              <q-item-label caption> {{ module.name }} </q-item-label>
            </q-item-section>

            <q-item-section top>
              <q-expansion-item
                expand-separator
                :icon="module.displayInfo.dependencies.icon"
                :header-class="module.displayInfo.dependencies.displayClass"
                :expand-icon-class="module.displayInfo.dependencies.displayClass"
                :label="module.displayInfo.dependencies.displayText"
              >
                <q-list dense flat separator class="rounded-borders">
                  <q-item
                    v-for="dep in module.dependencies"
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
                      <q-item-label>{{ simpleName(dep.name) }}</q-item-label>
                      <q-item-label caption>{{ dep.name }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-expansion-item>
            </q-item-section>

            <q-item-section top>
              <q-item v-if="!module.displayInfo.issues.expandable">
                <q-item-section avatar>
                  <q-icon
                    color="primary"
                    :name="module.displayInfo.issues.icon"
                    :class="module.displayInfo.issues.displayClass"
                  />
                </q-item-section>
                <q-item-section
                  :class="module.displayInfo.issues.displayClass">
                    {{ module.displayInfo.issues.displayText }}
                </q-item-section>
              </q-item>

              <q-expansion-item
                v-if="module.displayInfo.issues.expandable"
                expand-separator
                :icon             ="module.displayInfo.issues.icon"
                :header-class     ="module.displayInfo.issues.displayClass"
                :expand-icon-class="module.displayInfo.issues.displayClass"
                :label            ="module.displayInfo.issues.displayText"
              >
                <q-list dense flat separator class="rounded-borders">
                  <q-item v-for="issue in module.issues" :key="issue">
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
                  size="12px" flat dense round icon="published_with_changes"
                  @click="moduleStore.resolveModule(module.name)"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Resolve
                  </q-tooltip>
                </q-btn>
                <q-btn
                  class="gt-xs module-action"
                  size="12px" flat dense round icon="app_registration"
                  :disable="module.kind!='Web' || module.issues.length > 0"
                  @click="webAppDialog = { show: true, moduleName: module.name }"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Register application
                  </q-tooltip>
                </q-btn>
                <q-btn
                  class="gt-xs module-action"
                  size="12px" flat dense round icon="delete"
                  @click="deleteModule(module.name)"
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

    <q-dialog v-model="showUploadDialog">
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
            v-model="allowRedeployment"
            label="Allow automatic re-deployment of active applications"
          />
          <q-uploader
            :url="moduleStore.uploadURL + '?redeploy=' + allowRedeployment"
            label="Select '.xtc' file(s) to upload"
            multiple
            batch
            accept=".xtc"
            @uploading="$q.loading.show()"
            @uploaded="onUploaded"
            @failed="$q.loading.hide()"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <q-dialog v-model="webAppDialog.show">
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

          <q-input v-model="webAppDialog.deployment" hint="Deployment" autofocus>
            <template v-slot:prepend>
              <q-icon name="web_asset" />
            </template>
          </q-input>
        </q-card-section>

        <q-card-actions align="right" class="text-primary">
          <q-btn flat label="Cancel"   v-close-popup />
          <q-btn flat label="Register" v-close-popup @click="registerWebApp()" />
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
    const allowRedeployment = ref(true);

    onBeforeMount(() => {
      if (userStore.hasUser) {
        moduleStore.updateModules();
      }
    });

    watch(
      () => userStore.user,
      () => {
        if (userStore.hasUser) {
          moduleStore.updateModules();
        }
      }
    );

    function onUploaded(info) {
      const xhr      = info.xhr; // XMLHttpRequest
      const response = JSON.parse(xhr.response);
      if (response.length > 0) {
        var message = "";
        response.forEach(msg =>
            message += '<p>' + msg + '</p>');
        $q.dialog({
          title: "Module Upload",
          html: true,
          message: message,
        });
      }
      showUploadDialog.value=false;
      moduleStore.updateModules();
    }

    function registerWebApp() {
      webAppStore.registerWebApp(
        webAppDialog.value.deployment,
        webAppDialog.value.moduleName,
        false
      );
    }

    function deleteModule(name) {
      $q.dialog({
        title: "Confirm",
        message: "Are you sure you want to delete module `" + name + "`?",
        cancel: true,
      }).onOk(() => {
        moduleStore.deleteModule(name);
      });
    }

    function simpleName(name) {
      const ix = name.indexOf('.');
      return ix == -1 ? name : name.substring(0, ix);
    }

    return {
      userStore,
      moduleStore,
      webAppStore,
      showUploadDialog,
      webAppDialog,
      fileToUpload,
      allowRedeployment,
      onUploaded,
      registerWebApp,
      deleteModule,
      simpleName,
    };
  },
});
</script>

<style lang="sass">

.module-action.disabled
    color: silver
</style>