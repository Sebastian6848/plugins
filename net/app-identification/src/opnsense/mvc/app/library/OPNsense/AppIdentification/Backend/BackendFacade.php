<?php

namespace OPNsense\AppIdentification\Backend;

use OPNsense\Core\Backend;

class BackendFacade
{
    public function run(array $request): array
    {
        $payload = base64_encode(json_encode($request, JSON_UNESCAPED_SLASHES));
        $response = trim((new Backend())->configdRun('appidentification backend ' . escapeshellarg($payload)));
        $decoded = json_decode($response, true);
        if (is_array($decoded)) {
            return $decoded;
        }
        return ['status' => 'error', 'message' => $response !== '' ? $response : 'empty backend response'];
    }
}
