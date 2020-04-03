# ![VECTR](media/vectr-logo-small.png)

VECTR is a tool that facilitates tracking of your red and blue team testing activities to measure detection and prevention capabilities across different attack scenarios.  VECTR provides the ability to create assessment groups, which consist of a collection of Campaigns and supporting Test Cases to simulate adversary threats.  Campaigns can be broad and span activity across the kill chain, from initial compromise to privilege escalation and lateral movement and so on, or can be a narrow in scope to focus on specific detection layers, tools, and infrastructure.  VECTR is designed to promote full transparency between offense and defense, encourage training between team members, and improve detection & prevention success rate across the environment.   

VECTR is focused on common indicators of attack and behaviors that may be carried out by any number of threat actor groups, with varying objectives and levels of sophistication.  VECTR can also be used to replicate the step-by-step TTPs associated with specific groups and malware campaigns, however its primary purpose is to replicate attacker behaviors that span multiple threat actor groups and malware campaigns, past, present and future.  VECTR is meant to be used over time with targeted campaigns, iteration, and measurable enhancements to both red team skills and blue team detection capabilities.  Ultimately the goal of VECTR is to make a network resilient to all but the most sophisticated adversaries and insider attacks.

# ![VECTR](media/VectrMitreHeatmap55.png)

# ![VECTR](media/VectrCampaignView55.png)

# ![VECTR](media/ImportData.png)

# ![VECTR](media/historicalTrending.png)

## Getting Started

See the [wiki](https://github.com/SecurityRiskAdvisors/VECTR/wiki/Installation) for our installation guide

### Supported Platforms

Server Operating Systems
* Ubuntu LTS 16.04/18.04
* CentOS 7

If attempting to run VECTR in another OS see [Operating System Notes](https://github.com/SecurityRiskAdvisors/VECTR/wiki/Installation)

Client Browsers
* Chrome
* Firefox

Please read instructions carefully for [Upgrading a VECTR instance](https://github.com/SecurityRiskAdvisors/VECTR/wiki/Upgrading-an-existing-VECTR-installation)
	
## Usage

The VECTR webapp is available at https://your_docker_host:8081 Where your_docker_host is the URL set accordingly in the .env file. The port by default will be 8081 by default unless modified. Log in with the default credentials

**User: admin**

**Password: 11_ThisIsTheFirstPassword_11**

Please change your password after initial login in the user profile menu

Check out our [How-to Videos](https://github.com/SecurityRiskAdvisors/VECTR/wiki/How-To-Videos) for getting started in VECTR once you have it installed 

## General

* Presentation layer built on AngularJS with some Angular Material UI components
* Support for OAuth 2.0
* REST API powered by Apache CXF and JAX-RS
* Support for TLS endpoints (VECTR Community Edition will auto-generate an untrusted self-signed cert or can be supplied with certs)

## Documentation

### Feature Breakdowns By Release

[VECTR v5.5.0 Feature Breakdown](NEED NEW PDF)

## Team
LEAD PROGRAMMERS:
* Carl Vonderheid
* Galen Fisher

PROGRAMMERS:
* Daniel Hong
* Andrew Scott
* Patrick Hislop
* Nick Galante

DevOps Engineering:
* Paul Spencer

DESIGN & REQUIREMENTS:
* Phil Wainwright

GRAPHIC DESIGN & MARKETING:
* Doug Webster

[![Security Risk Advisors](media/SRA-logo-primary-small.png)](https://securityriskadvisors.com)

## License

Please see the [EULA](./VECTR%20End%20User%20License%20Agreement.pdf)

Atomic Red [LICENSE](https://github.com/redcanaryco/atomic-red-team/blob/master/LICENSE.txt)

