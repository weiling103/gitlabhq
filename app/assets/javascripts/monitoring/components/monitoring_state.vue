<script>
  import gettingStartedSvg from 'empty_states/monitoring/_getting_started.svg';
  import loadingSvg from 'empty_states/monitoring/_loading.svg';
  import unableToConnectSvg from 'empty_states/monitoring/_unable_to_connect.svg';

  export default {
    props: {
      documentationPath: {
        type: String,
        required: true,
      },
      settingsPath: {
        type: String,
        required: false,
        default: '',
      },
      selectedState: {
        type: String,
        required: true,
      },
    },
    data() {
      return {
        states: {
          gettingStarted: {
            svg: gettingStartedSvg,
            title: 'Get started with performance monitoring',
            description: 'Stay updated about the performance and health of your environment by configuring Prometheus to monitor your deployments.',
            buttonText: 'Configure Prometheus',
          },
          loading: {
            svg: loadingSvg,
            title: 'Waiting for performance data',
            description: 'Creating graphs uses the data from the Prometheus server. If this takes a long time, ensure that data is available.',
            buttonText: 'View documentation',
          },
          unableToConnect: {
            svg: unableToConnectSvg,
            title: 'Unable to connect to Prometheus server',
            description: 'Ensure connectivity is available from the GitLab server to the ',
            buttonText: 'View documentation',
          },
        },
      };
    },
    computed: {
      currentState() {
        return this.states[this.selectedState];
      },

      buttonPath() {
        if (this.selectedState === 'gettingStarted') {
          return this.settingsPath;
        }
        return this.documentationPath;
      },

      showButtonDescription() {
        if (this.selectedState === 'unableToConnect') return true;
        return false;
      },
    },
  };
</script>
<template>
  <div 
    class="prometheus-state">
    <div 
      class="row">
      <div 
        class="col-md-4 col-md-offset-4 state-svg" 
        v-html="currentState.svg">
      </div>
    </div>
    <div 
      class="row">
      <div 
        class="col-md-6 col-md-offset-3">
        <h4 
          class="text-center state-title">
          {{currentState.title}}
        </h4>
      </div>
    </div>
    <div 
      class="row">
      <div 
        class="col-md-6 col-md-offset-3">
        <div 
          class="description-text text-center state-description">
            {{currentState.description}}
            <a 
              :href="settingsPath"
              v-if="showButtonDescription">
              Prometheus server
            </a>
        </div>
      </div>
    </div>
    <div 
      class="row state-button-section">
      <div 
        class="col-md-4 col-md-offset-4 text-center state-button">
        <a 
          class="btn btn-success" 
          :href="buttonPath">
            {{currentState.buttonText}}
        </a>
      </div>
    </div>
  </div>
</template>
