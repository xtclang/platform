import { defineStore } from 'pinia';
import { apiWebApp } from "boot/axios";
import { useQuasar } from "quasar";

export const useWebAppStore = defineStore('webApp', {
  state: () => ({
    webAppsJSON: {},
    $q: useQuasar()
  }),

  getters: {
    webApps: (state) => state.webAppsJSON,
  },

  actions: {

    enhance() {
      delete this.webApps['$type']
    },

    updateWebApps() {
      this.$q.loading.show();
      apiWebApp
        .get("/all")
        .then((response) => {
          this.webAppsJSON = response.data;
          this.enhance();
        })
        .catch(() => {
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Could not fetch webapps",
            icon: "report_problem",
          });
        })
        .finally(() => {
          this.$q.loading.hide();
        });
    },

    registerWebApp(domain, moduleName, update) {
      this.$q.loading.show();
      apiWebApp
        .post(`/register/${domain}/${moduleName}`)
        .then((response) => {
          if (update) this.updateWebApp()
        })
        .catch(() => {
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Could not register the webapp",
            icon: "report_problem",
          });
        })
        .finally(() => {
          this.$q.loading.hide();
        });
    },


  },
});
