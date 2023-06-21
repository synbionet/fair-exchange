// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {Service} from "../BionetTypes.sol";
import {WithStorage} from "../libraries/LibStorage.sol";
import {NoZeroAddress, UnAuthorizedCaller} from "../Errors.sol";

///@dev Manage information related to a Service. Each service may results in many
/// exchanges.
contract ServiceFacet is WithStorage {
    // reverts when a service is not found
    error ServiceDoesNotExist();

    // emitted when:
    // a service is deactivated by the owner
    event ServiceDeactivated(uint256 indexed id, uint256 when);
    // the meta uri has changed
    event ServiceUpdatedMetaUri(uint256 indexed id, string uri, uint256 when);
    // a service is created
    event ServiceCreated(
        uint256 indexed id,
        address indexed owner,
        string name,
        string uri,
        uint256 when
    );

    /// @dev Create a service. The owner will be the caller.
    ///
    /// Reverts if:
    ///   - caller is the 0x0 address
    ///
    /// @param _name of the service
    /// @param _uri of the metadata, usually json file
    /// @return sid the identifier for the service
    function createService(string calldata _name, string calldata _uri)
        external
        returns (uint256 sid)
    {
        if (msg.sender == address(0x0)) revert NoZeroAddress();

        // TODO: Check the caller is vetted Bionet member

        sid = counters().nextServiceId++;
        bionetStore().services[sid] = Service({
            id: sid,
            owner: msg.sender,
            name: _name,
            metaUri: _uri,
            active: true
        });

        emit ServiceCreated(sid, msg.sender, _name, _uri, block.timestamp);
    }

    /// @dev return the Service for a given ID.
    /// @param _serviceId the service id
    /// @return exists true if service exists, else false
    /// @return serv a memory copy of the service
    function getService(uint256 _serviceId)
        external
        view
        returns (bool exists, Service memory serv)
    {
        serv = bionetStore().services[_serviceId];
        if (serv.owner != address(0x0)) exists = true;
    }

    /// @dev Update the metadata uri for a service.  Caller must be the service
    /// owner.
    ///
    /// Reverts if:
    ///   - the service doesn't exist
    ///   - the caller is the 0x0 address
    ///   - the caller is not the owner of the service
    ///
    /// @param _serviceId id of the service
    /// @param _metaUri url of the metadata
    /// @return ok if it was successfully updated
    function updateServiceMeta(uint256 _serviceId, string calldata _metaUri)
        external
        returns (bool ok)
    {
        Service storage serv = bionetStore().services[_serviceId];
        _checkCaller(serv.owner);

        serv.metaUri = _metaUri;
        ok = true;

        emit ServiceUpdatedMetaUri(_serviceId, _metaUri, block.timestamp);
    }

    /// @dev Deactive a service. This can be used to remove a service from a list of
    /// offerings. Note, this doesn't remove the service and it's information. It
    /// simply sets a flag that can be checked. Caller must be the service owner.
    ///
    /// Reverts if:
    ///   - the service doesn't exist
    ///   - the caller is the 0x0 address
    ///   - the caller is not the owner of the service
    ///
    /// @param _serviceId id of the service
    /// @return ok if it was successfully deactivated
    function deactivateService(uint256 _serviceId) external returns (bool ok) {
        Service storage serv = bionetStore().services[_serviceId];
        _checkCaller(serv.owner);

        serv.active = false;
        ok = true;

        emit ServiceDeactivated(_serviceId, block.timestamp);
    }

    /// @dev Check if a service is active.
    /// @param _serviceId the service id
    /// @return isactive true or false
    function isActiveService(uint256 _serviceId)
        external
        view
        returns (bool isactive)
    {
        Service memory serv = bionetStore().services[_serviceId];
        if (serv.owner == address(0x0)) return false;
        isactive = serv.active;
    }

    /// ****
    /// Internal stuff
    /// ****

    /// @dev helper to validate information
    function _checkCaller(address _owner) internal view {
        if (_owner == address(0x0)) revert ServiceDoesNotExist();
        if (msg.sender == address(0x0)) revert NoZeroAddress();
        if (msg.sender != _owner) revert UnAuthorizedCaller();
    }
}
