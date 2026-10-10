package com.enterprise.migration.adapter.service;

import com.enterprise.migration.adapter.config.IbmiProperties;
import com.enterprise.migration.adapter.dto.InvoiceResponse;
import com.enterprise.migration.adapter.exception.IbmiHostUnavailableException;
import com.ibm.as400.access.AS400;
import com.ibm.as400.access.AS400Message;
import com.ibm.as400.access.AS400PackedDecimal;
import com.ibm.as400.access.AS400Text;
import com.ibm.as400.access.ProgramCall;
import com.ibm.as400.access.ProgramParameter;
import com.ibm.as400.access.QSYSObjectPathName;
import com.ibm.as400.access.SocketProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
public class IbmiInvoiceService implements InvoiceService {

    private static final Logger log = LoggerFactory.getLogger(IbmiInvoiceService.class);

    private final IbmiProperties ibmiProperties;

    public IbmiInvoiceService(IbmiProperties ibmiProperties) {
        this.ibmiProperties = ibmiProperties;
    }

    @Override
    public InvoiceResponse getInvoice(String invId) {
        if (invId == null || invId.trim().isEmpty()) {
            throw new IllegalArgumentException("Invoice ID must not be empty");
        }

        String host = ibmiProperties.getHost();
        String user = ibmiProperties.getUser();
        String password = ibmiProperties.getPassword();
        String library = ibmiProperties.getLibrary();
        String program = ibmiProperties.getProgram();

        String programPath = QSYSObjectPathName.toPath(library, program, "PGM");
        log.info("Connecting to IBM i host '{}' as user '{}' to call '{}' for invId='{}'",
                host, user, programPath, invId);

        AS400 as400 = null;
        try {
            if (password != null && !password.isEmpty()) {
                as400 = new AS400(host, user, password);
            } else {
                as400 = new AS400(host, user);
            }

            // Configure socket timeouts: fail fast within 5s if host is offline / unreachable
            SocketProperties socketProperties = new SocketProperties();
            socketProperties.setLoginTimeout(5000);
            socketProperties.setSoTimeout(15000);
            as400.setSocketProperties(socketProperties);

            // 1. inInvId: char(10)
            AS400Text textInvId = new AS400Text(10, as400);
            byte[] inInvIdBytes = textInvId.toBytes(invId);
            ProgramParameter param1InvId = new ProgramParameter(inInvIdBytes);

            // 2. outCustNo: packed(6:0) -> 4 bytes
            AS400PackedDecimal packedCustNo = new AS400PackedDecimal(6, 0);
            ProgramParameter param2CustNo = new ProgramParameter(packedCustNo.getByteLength());

            // 3. outInvAmt: packed(11:2) -> 6 bytes
            AS400PackedDecimal packedInvAmt = new AS400PackedDecimal(11, 2);
            ProgramParameter param3InvAmt = new ProgramParameter(packedInvAmt.getByteLength());

            // 4. outStatus: char(1) -> 1 byte
            AS400Text textStatus = new AS400Text(1, as400);
            ProgramParameter param4Status = new ProgramParameter(textStatus.getByteLength());

            // 5. outDueDate: packed(8:0) -> 5 bytes
            AS400PackedDecimal packedDueDate = new AS400PackedDecimal(8, 0);
            ProgramParameter param5DueDate = new ProgramParameter(packedDueDate.getByteLength());

            // 6. outFound: char(1) -> 1 byte
            AS400Text textFound = new AS400Text(1, as400);
            ProgramParameter param6Found = new ProgramParameter(textFound.getByteLength());

            ProgramParameter[] parameterList = new ProgramParameter[] {
                    param1InvId,
                    param2CustNo,
                    param3InvAmt,
                    param4Status,
                    param5DueDate,
                    param6Found
            };

            ProgramCall programCall = new ProgramCall(as400, programPath, parameterList);
            boolean executed = programCall.run();

            if (!executed) {
                StringBuilder errorDetails = new StringBuilder("ProgramCall to " + programPath + " failed: ");
                AS400Message[] messageList = programCall.getMessageList();
                if (messageList != null) {
                    for (AS400Message msg : messageList) {
                        errorDetails.append(msg.getID()).append(": ").append(msg.getText()).append("; ");
                    }
                }
                log.error("IBM i ProgramCall error: {}", errorDetails);
                throw new RuntimeException(errorDetails.toString());
            }

            // Unpack results
            BigDecimal custNoObj = (BigDecimal) packedCustNo.toObject(param2CustNo.getOutputData());
            BigDecimal invAmtObj = (BigDecimal) packedInvAmt.toObject(param3InvAmt.getOutputData());
            String statusObj = (String) textStatus.toObject(param4Status.getOutputData());
            BigDecimal dueDateObj = (BigDecimal) packedDueDate.toObject(param5DueDate.getOutputData());
            String foundObj = (String) textFound.toObject(param6Found.getOutputData());

            String statusVal = statusObj != null ? statusObj.trim() : "";
            String foundVal = foundObj != null ? foundObj.trim() : "";
            Long custNoVal = custNoObj != null ? custNoObj.longValue() : null;
            Long dueDateVal = dueDateObj != null ? dueDateObj.longValue() : null;

            log.info("ProgramCall returned: found='{}', custNo={}, invAmt={}, status='{}', duDate={}",
                    foundVal, custNoVal, invAmtObj, statusVal, dueDateVal);

            return new InvoiceResponse(dueDateVal, custNoVal, invAmtObj, statusVal, foundVal);

        } catch (Exception e) {
            log.error("Exception during IBM i ProgramCall for invoice {}: {}", invId, e.getMessage(), e);
            if (isConnectivityError(e)) {
                throw new IbmiHostUnavailableException(invId, host, e.getMessage(), e);
            }
            throw new RuntimeException("Failed to call IBM i program for invoice " + invId + ": " + e.getMessage(), e);
        } finally {
            if (as400 != null) {
                try {
                    as400.disconnectAllServices();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private boolean isConnectivityError(Throwable e) {
        Throwable curr = e;
        while (curr != null) {
            if (curr instanceof java.net.SocketException
                    || curr instanceof java.net.ConnectException
                    || curr instanceof java.net.NoRouteToHostException
                    || curr instanceof java.net.UnknownHostException
                    || curr instanceof java.net.SocketTimeoutException
                    || curr instanceof com.ibm.as400.access.ConnectionDroppedException
                    || curr instanceof com.ibm.as400.access.ServerStartupException) {
                return true;
            }
            String msg = curr.getMessage();
            if (msg != null) {
                String lower = msg.toLowerCase();
                if (lower.contains("connection refused")
                        || lower.contains("host is unreachable")
                        || lower.contains("unreachable")
                        || lower.contains("timed out")
                        || lower.contains("timeout")
                        || lower.contains("cannot connect")
                        || lower.contains("connection dropped")
                        || lower.contains("no route to host")
                        || lower.contains("not connected")) {
                    return true;
                }
            }
            curr = curr.getCause();
        }
        return false;
    }
}

